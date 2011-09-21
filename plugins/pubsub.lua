local jid_bare = require "util.jid".bare;

local xmlns_pubsub = "http://jabber.org/protocol/pubsub";
local xmlns_pubsub_event = "http://jabber.org/protocol/pubsub#event";
local xmlns_pubsub_errors = "http://jabber.org/protocol/pubsub#errors";

local pubsub = {};
local pubsub_mt = { __index = pubsub };

function verse.plugins.pubsub(stream)
	stream.pubsub = setmetatable({ stream = stream }, pubsub_mt);
	stream:hook("message", function (message)
		for pubsub_event in message:childtags("event", xmlns_pubsub_event) do
			local items = pubsub_event:get_child("items");
			if items then
				local node = items.attr.node;
				for item in items:childtags("item") do
					stream:event("pubsub/event", {
						from = message.attr.from;
						node = node;
						item = item;
					});
				end
			end
		end
	end);
	return true;
end

function pubsub:subscribe(server, node, jid, callback)
	self.stream:send_iq(verse.iq({ to = server, type = "set" })
		:tag("pubsub", { xmlns = xmlns_pubsub })
			:tag("subscribe", { node = node, jid = jid or jid_bare(self.stream.jid) })
	, function (result)
		if callback then
			if result.attr.type == "result" then
				callback(true);
			else
				callback(false, result:get_error());
			end
		end
	  end
	);
end

function pubsub:publish(server, node, id, item, callback)
	self.stream:send_iq(verse.iq({ to = server, type = "set" })
		:tag("pubsub", { xmlns = xmlns_pubsub })
			:tag("publish", { node = node })
				:tag("item", { id = id })
					:add_child(item)
	, function (result)
		if callback then
			if result.attr.type == "result" then
				callback(true);
			else
				callback(false, result:get_error());
			end
		end
	  end
	);
end
