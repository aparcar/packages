/*
 * Copyright (C) 2024 OpenWrt.org
 *
 * This is free software, licensed under the GNU General Public License v2.
 * See /LICENSE for more information.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <yaml.h>

#include <ucode/module.h>
#include <ucode/types.h>

#define err_return(err) do { last_error = err; return NULL; } while(0)

static uc_resource_type_t *document_type;
static const char *last_error = NULL;

/* Forward declarations */
static uc_value_t *parse_node(uc_vm_t *vm, yaml_document_t *doc, yaml_node_t *node);

static uc_value_t *
parse_scalar(uc_vm_t *vm, yaml_node_t *node)
{
	const char *value = (const char *)node->data.scalar.value;
	size_t length = node->data.scalar.length;
	char *end;
	long long ll;
	double d;

	if (!value || length == 0)
		return ucv_string_new("");

	/* Handle null values */
	if (length == 1 && value[0] == '~')
		return NULL;

	if ((length == 4 && strcasecmp(value, "null") == 0) ||
	    (length == 4 && strcasecmp(value, "Null") == 0) ||
	    (length == 4 && strcasecmp(value, "NULL") == 0))
		return NULL;

	/* Handle boolean values */
	if ((length == 4 && strcasecmp(value, "true") == 0) ||
	    (length == 3 && strcasecmp(value, "yes") == 0) ||
	    (length == 2 && strcasecmp(value, "on") == 0))
		return ucv_boolean_new(true);

	if ((length == 5 && strcasecmp(value, "false") == 0) ||
	    (length == 2 && strcasecmp(value, "no") == 0) ||
	    (length == 3 && strcasecmp(value, "off") == 0))
		return ucv_boolean_new(false);

	/* Handle integer values */
	if (node->data.scalar.style == YAML_PLAIN_SCALAR_STYLE) {
		ll = strtoll(value, &end, 0);
		if (end != value && *end == '\0')
			return ucv_int64_new(ll);

		/* Handle floating point values */
		d = strtod(value, &end);
		if (end != value && *end == '\0')
			return ucv_double_new(d);

		/* Handle special float values */
		if ((length == 4 && strcasecmp(value, ".inf") == 0) ||
		    (length == 4 && strcasecmp(value, ".Inf") == 0) ||
		    (length == 4 && strcasecmp(value, ".INF") == 0))
			return ucv_double_new(1.0 / 0.0);

		if ((length == 5 && strcasecmp(value, "-.inf") == 0) ||
		    (length == 5 && strcasecmp(value, "-.Inf") == 0) ||
		    (length == 5 && strcasecmp(value, "-.INF") == 0))
			return ucv_double_new(-1.0 / 0.0);

		if ((length == 4 && strcasecmp(value, ".nan") == 0) ||
		    (length == 4 && strcasecmp(value, ".NaN") == 0) ||
		    (length == 4 && strcasecmp(value, ".NAN") == 0))
			return ucv_double_new(0.0 / 0.0);
	}

	/* Default to string */
	return ucv_string_new_length(value, length);
}

static uc_value_t *
parse_sequence(uc_vm_t *vm, yaml_document_t *doc, yaml_node_t *node)
{
	uc_value_t *arr = ucv_array_new(vm);
	yaml_node_item_t *item;

	if (!arr)
		return NULL;

	for (item = node->data.sequence.items.start;
	     item < node->data.sequence.items.top; item++) {
		yaml_node_t *child = yaml_document_get_node(doc, *item);
		uc_value_t *val = child ? parse_node(vm, doc, child) : NULL;
		ucv_array_push(arr, val);
	}

	return arr;
}

static uc_value_t *
parse_mapping(uc_vm_t *vm, yaml_document_t *doc, yaml_node_t *node)
{
	uc_value_t *obj = ucv_object_new(vm);
	yaml_node_pair_t *pair;

	if (!obj)
		return NULL;

	for (pair = node->data.mapping.pairs.start;
	     pair < node->data.mapping.pairs.top; pair++) {
		yaml_node_t *key_node = yaml_document_get_node(doc, pair->key);
		yaml_node_t *value_node = yaml_document_get_node(doc, pair->value);

		if (!key_node || key_node->type != YAML_SCALAR_NODE)
			continue;

		const char *key = (const char *)key_node->data.scalar.value;
		uc_value_t *val = value_node ? parse_node(vm, doc, value_node) : NULL;

		ucv_object_add(obj, key, val);
	}

	return obj;
}

static uc_value_t *
parse_node(uc_vm_t *vm, yaml_document_t *doc, yaml_node_t *node)
{
	if (!node)
		return NULL;

	switch (node->type) {
	case YAML_SCALAR_NODE:
		return parse_scalar(vm, node);
	case YAML_SEQUENCE_NODE:
		return parse_sequence(vm, doc, node);
	case YAML_MAPPING_NODE:
		return parse_mapping(vm, doc, node);
	default:
		return NULL;
	}
}

/**
 * Parse a YAML string into a ucode value.
 *
 * @function module:yaml#parse
 *
 * @param {string} yaml_string
 * The YAML string to parse.
 *
 * @returns {*}
 * The parsed value (object, array, string, number, boolean, or null).
 * Returns null on parse error.
 */
static uc_value_t *
uc_yaml_parse(uc_vm_t *vm, size_t nargs)
{
	uc_value_t *str = uc_fn_arg(0);
	yaml_parser_t parser;
	yaml_document_t document;
	yaml_node_t *root;
	uc_value_t *result = NULL;
	const char *input;
	size_t len;

	last_error = NULL;

	if (ucv_type(str) != UC_STRING)
		err_return("Argument must be a string");

	input = ucv_string_get(str);
	len = ucv_string_length(str);

	if (!yaml_parser_initialize(&parser))
		err_return("Failed to initialize YAML parser");

	yaml_parser_set_input_string(&parser, (const unsigned char *)input, len);

	if (!yaml_parser_load(&parser, &document)) {
		last_error = parser.problem ? parser.problem : "YAML parse error";
		yaml_parser_delete(&parser);
		return NULL;
	}

	root = yaml_document_get_root_node(&document);
	if (root)
		result = parse_node(vm, &document, root);

	yaml_document_delete(&document);
	yaml_parser_delete(&parser);

	return result;
}

/* YAML emitter output buffer */
typedef struct {
	char *data;
	size_t size;
	size_t capacity;
} yaml_output_buffer_t;

static int
yaml_output_handler(void *data, unsigned char *buffer, size_t size)
{
	yaml_output_buffer_t *out = (yaml_output_buffer_t *)data;
	size_t new_capacity;
	char *new_data;

	if (out->size + size > out->capacity) {
		new_capacity = out->capacity ? out->capacity * 2 : 1024;
		while (new_capacity < out->size + size)
			new_capacity *= 2;

		new_data = realloc(out->data, new_capacity);
		if (!new_data)
			return 0;

		out->data = new_data;
		out->capacity = new_capacity;
	}

	memcpy(out->data + out->size, buffer, size);
	out->size += size;

	return 1;
}

static int emit_value(yaml_emitter_t *emitter, uc_value_t *val);

static int
emit_scalar(yaml_emitter_t *emitter, const char *value, size_t length,
            yaml_scalar_style_t style)
{
	yaml_event_t event;

	if (!yaml_scalar_event_initialize(&event, NULL, NULL,
	                                  (yaml_char_t *)value, length,
	                                  1, 1, style))
		return 0;

	if (!yaml_emitter_emit(emitter, &event))
		return 0;

	return 1;
}

static int
emit_array(yaml_emitter_t *emitter, uc_value_t *arr)
{
	yaml_event_t event;
	size_t i, len;

	if (!yaml_sequence_start_event_initialize(&event, NULL, NULL, 1,
	                                          YAML_ANY_SEQUENCE_STYLE))
		return 0;

	if (!yaml_emitter_emit(emitter, &event))
		return 0;

	len = ucv_array_length(arr);
	for (i = 0; i < len; i++) {
		if (!emit_value(emitter, ucv_array_get(arr, i)))
			return 0;
	}

	if (!yaml_sequence_end_event_initialize(&event))
		return 0;

	if (!yaml_emitter_emit(emitter, &event))
		return 0;

	return 1;
}

static int
emit_object(yaml_emitter_t *emitter, uc_value_t *obj)
{
	yaml_event_t event;
	uc_value_t *key, *val;
	const char *key_str;

	if (!yaml_mapping_start_event_initialize(&event, NULL, NULL, 1,
	                                         YAML_ANY_MAPPING_STYLE))
		return 0;

	if (!yaml_emitter_emit(emitter, &event))
		return 0;

	ucv_object_foreach(obj, k, v) {
		key_str = k;
		if (!emit_scalar(emitter, key_str, strlen(key_str),
		                 YAML_ANY_SCALAR_STYLE))
			return 0;

		if (!emit_value(emitter, v))
			return 0;
	}

	if (!yaml_mapping_end_event_initialize(&event))
		return 0;

	if (!yaml_emitter_emit(emitter, &event))
		return 0;

	return 1;
}

static int
emit_value(yaml_emitter_t *emitter, uc_value_t *val)
{
	char buf[64];
	const char *str;
	size_t len;
	int64_t i;
	double d;

	if (!val)
		return emit_scalar(emitter, "null", 4, YAML_PLAIN_SCALAR_STYLE);

	switch (ucv_type(val)) {
	case UC_NULL:
		return emit_scalar(emitter, "null", 4, YAML_PLAIN_SCALAR_STYLE);

	case UC_BOOLEAN:
		if (ucv_boolean_get(val))
			return emit_scalar(emitter, "true", 4, YAML_PLAIN_SCALAR_STYLE);
		else
			return emit_scalar(emitter, "false", 5, YAML_PLAIN_SCALAR_STYLE);

	case UC_INTEGER:
		i = ucv_int64_get(val);
		len = snprintf(buf, sizeof(buf), "%lld", (long long)i);
		return emit_scalar(emitter, buf, len, YAML_PLAIN_SCALAR_STYLE);

	case UC_DOUBLE:
		d = ucv_double_get(val);
		if (d != d) /* NaN */
			return emit_scalar(emitter, ".nan", 4, YAML_PLAIN_SCALAR_STYLE);
		else if (d == 1.0 / 0.0) /* +Inf */
			return emit_scalar(emitter, ".inf", 4, YAML_PLAIN_SCALAR_STYLE);
		else if (d == -1.0 / 0.0) /* -Inf */
			return emit_scalar(emitter, "-.inf", 5, YAML_PLAIN_SCALAR_STYLE);
		len = snprintf(buf, sizeof(buf), "%g", d);
		return emit_scalar(emitter, buf, len, YAML_PLAIN_SCALAR_STYLE);

	case UC_STRING:
		str = ucv_string_get(val);
		len = ucv_string_length(val);
		return emit_scalar(emitter, str, len, YAML_ANY_SCALAR_STYLE);

	case UC_ARRAY:
		return emit_array(emitter, val);

	case UC_OBJECT:
		return emit_object(emitter, val);

	default:
		/* For unsupported types, emit as string representation */
		str = ucv_to_string(NULL, val);
		if (str) {
			len = strlen(str);
			int ret = emit_scalar(emitter, str, len, YAML_SINGLE_QUOTED_SCALAR_STYLE);
			free((void *)str);
			return ret;
		}
		return emit_scalar(emitter, "null", 4, YAML_PLAIN_SCALAR_STYLE);
	}
}

/**
 * Convert a ucode value to a YAML string.
 *
 * @function module:yaml#stringify
 *
 * @param {*} value
 * The value to convert to YAML.
 *
 * @returns {string}
 * The YAML string representation, or null on error.
 */
static uc_value_t *
uc_yaml_stringify(uc_vm_t *vm, size_t nargs)
{
	uc_value_t *val = uc_fn_arg(0);
	yaml_emitter_t emitter;
	yaml_event_t event;
	yaml_output_buffer_t out = { NULL, 0, 0 };
	uc_value_t *result = NULL;

	last_error = NULL;

	if (!yaml_emitter_initialize(&emitter)) {
		last_error = "Failed to initialize YAML emitter";
		return NULL;
	}

	yaml_emitter_set_output(&emitter, yaml_output_handler, &out);
	yaml_emitter_set_unicode(&emitter, 1);

	/* Emit stream start */
	if (!yaml_stream_start_event_initialize(&event, YAML_UTF8_ENCODING))
		goto error;
	if (!yaml_emitter_emit(&emitter, &event))
		goto error;

	/* Emit document start */
	if (!yaml_document_start_event_initialize(&event, NULL, NULL, NULL, 1))
		goto error;
	if (!yaml_emitter_emit(&emitter, &event))
		goto error;

	/* Emit the value */
	if (!emit_value(&emitter, val))
		goto error;

	/* Emit document end */
	if (!yaml_document_end_event_initialize(&event, 1))
		goto error;
	if (!yaml_emitter_emit(&emitter, &event))
		goto error;

	/* Emit stream end */
	if (!yaml_stream_end_event_initialize(&event))
		goto error;
	if (!yaml_emitter_emit(&emitter, &event))
		goto error;

	yaml_emitter_delete(&emitter);

	if (out.data) {
		result = ucv_string_new_length(out.data, out.size);
		free(out.data);
	}

	return result;

error:
	last_error = emitter.problem ? emitter.problem : "YAML emit error";
	yaml_emitter_delete(&emitter);
	free(out.data);
	return NULL;
}

/**
 * Get the last error message from a parse or stringify operation.
 *
 * @function module:yaml#error
 *
 * @returns {string|null}
 * The last error message, or null if no error occurred.
 */
static uc_value_t *
uc_yaml_error(uc_vm_t *vm, size_t nargs)
{
	if (last_error)
		return ucv_string_new(last_error);

	return NULL;
}

static const uc_function_list_t yaml_fns[] = {
	{ "parse",      uc_yaml_parse },
	{ "stringify",  uc_yaml_stringify },
	{ "error",      uc_yaml_error },
};

void uc_module_init(uc_vm_t *vm, uc_value_t *scope)
{
	uc_function_list_register(scope, yaml_fns);
}
