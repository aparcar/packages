#!/usr/bin/lua

local json = require "cjson"
local util = require "luci.util"

local function scrape()
	local status = json.decode(util.exec("batadv-vis -f jsondoc"))
	local labels = {
	  source_version = status.source_version,
	  algorithm = status.algorithm
	}

	metric("batadv_status", "gauge", labels, 1)

	local metric_batadv_link_metric = metric("batadv_link_metric","gauge")
	local metric_batadv_clients = metric("batadv_clients","gauge")

	local nodes = status.vis
	for _, node in pairs(nodes) do
		for _, neighbor in pairs(neighbors) do
			local labels = {
			  source = neighbor.router,
			  target = neighbor.neighbor
			}
			metric_batadv_link_metric(labels, neighbor.metric)
		end
		metric_badadv_clients({ node = node.primary}, table.getn(node.clients))
	end

return { scrape = scrape }
