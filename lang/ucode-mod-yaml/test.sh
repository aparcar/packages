#!/bin/sh

[ "$1" = ucode-mod-yaml ] || exit 0

ucode - << 'EOF'

import { parse, stringify, error } from 'yaml';

let failed = 0;

function assert(cond, msg) {
	if (!cond) {
		warn(`FAIL: ${msg}\n`);
		failed++;
	}
}

function assert_eq(a, b, msg) {
	if (a != b) {
		warn(`FAIL: ${msg}: expected '${b}', got '${a}'\n`);
		failed++;
	}
}

// Test 1: Parse simple key-value
let obj = parse('key: value');
assert(type(obj) == 'object', 'parse returns object');
assert_eq(obj.key, 'value', 'simple key-value');

// Test 2: Parse nested structure
obj = parse('root:\n  child: nested');
assert_eq(obj.root.child, 'nested', 'nested structure');

// Test 3: Parse array/sequence
obj = parse('items:\n  - one\n  - two\n  - three');
assert(type(obj.items) == 'array', 'sequence is array');
assert_eq(length(obj.items), 3, 'sequence length');
assert_eq(obj.items[0], 'one', 'sequence first item');
assert_eq(obj.items[2], 'three', 'sequence last item');

// Test 4: Parse integers
obj = parse('num: 42\nneg: -10\nhex: 0xff');
assert_eq(obj.num, 42, 'positive integer');
assert_eq(obj.neg, -10, 'negative integer');
assert_eq(obj.hex, 255, 'hex integer');

// Test 5: Parse floats
obj = parse('pi: 3.14\nsci: 1.5e10');
assert(obj.pi > 3.13 && obj.pi < 3.15, 'float value');
assert(obj.sci > 1e10, 'scientific notation');

// Test 6: Parse booleans - true variants
obj = parse('a: true\nb: True\nc: yes\nd: Yes\ne: on\nf: On');
assert_eq(obj.a, true, 'bool true');
assert_eq(obj.b, true, 'bool True');
assert_eq(obj.c, true, 'bool yes');
assert_eq(obj.d, true, 'bool Yes');
assert_eq(obj.e, true, 'bool on');
assert_eq(obj.f, true, 'bool On');

// Test 7: Parse booleans - false variants
obj = parse('a: false\nb: False\nc: no\nd: No\ne: off\nf: Off');
assert_eq(obj.a, false, 'bool false');
assert_eq(obj.b, false, 'bool False');
assert_eq(obj.c, false, 'bool no');
assert_eq(obj.d, false, 'bool No');
assert_eq(obj.e, false, 'bool off');
assert_eq(obj.f, false, 'bool Off');

// Test 8: Parse null variants
obj = parse('a: null\nb: ~\nc: Null');
assert_eq(obj.a, null, 'null value');
assert_eq(obj.b, null, 'tilde null');
assert_eq(obj.c, null, 'Null value');

// Test 9: Parse quoted strings (preserve as string)
obj = parse('a: "true"\nb: "123"');
assert_eq(obj.a, 'true', 'quoted true is string');
assert_eq(obj.b, '123', 'quoted number is string');

// Test 10: Stringify simple object
let yaml_out = stringify({ name: 'test', value: 42 });
assert(yaml_out != null, 'stringify returns string');
assert(index(yaml_out, 'name') >= 0, 'stringify contains key');

// Test 11: Stringify array
yaml_out = stringify({ items: ['a', 'b', 'c'] });
assert(yaml_out != null, 'stringify array');

// Test 12: Stringify nested
yaml_out = stringify({ outer: { inner: 'value' } });
assert(yaml_out != null, 'stringify nested');

// Test 13: Stringify booleans
yaml_out = stringify({ flag: true, other: false });
assert(index(yaml_out, 'true') >= 0, 'stringify true');
assert(index(yaml_out, 'false') >= 0, 'stringify false');

// Test 14: Stringify null
yaml_out = stringify({ empty: null });
assert(index(yaml_out, 'null') >= 0, 'stringify null');

// Test 15: Round-trip test
let original = {
	string: 'hello',
	number: 123,
	float: 3.14,
	bool_t: true,
	bool_f: false,
	list: [1, 2, 3],
	nested: { key: 'value' }
};
let yaml_str = stringify(original);
let parsed = parse(yaml_str);
assert_eq(parsed.string, original.string, 'round-trip string');
assert_eq(parsed.number, original.number, 'round-trip number');
assert_eq(parsed.bool_t, original.bool_t, 'round-trip bool true');
assert_eq(parsed.bool_f, original.bool_f, 'round-trip bool false');
assert_eq(length(parsed.list), 3, 'round-trip array length');
assert_eq(parsed.nested.key, 'value', 'round-trip nested');

// Test 16: Error handling - invalid YAML
parse('invalid: yaml: content: [unclosed');
let err = error();
assert(err != null, 'error() returns message for invalid YAML');

// Test 17: Empty input
obj = parse('');
assert(obj == null, 'empty string returns null');

// Test 18: Parse multi-document (only first)
obj = parse('first: doc\n---\nsecond: doc');
assert_eq(obj.first, 'doc', 'multi-doc parses first');

// Report results
if (failed > 0) {
	warn(`\n${failed} test(s) failed!\n`);
	exit(1);
}

print('All tests passed!\n');

EOF
