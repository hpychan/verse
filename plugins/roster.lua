local xmlns_roster = "jabber:iq:roster";
local bare_jid = require "util.jid".bare;
local t_insert = table.insert;

function verse.plugins.roster(stream)
	local roster = {
		items = {};
		-- TODO:
		-- groups = {};
		-- ver = nil;
	};
	stream.roster = roster;

	local function item_lua2xml(item_table)
		local xml_item = verse.stanza("item", { xmlns = xmlns_roster });
		for k, v in pairs(item_table) do
			if k ~= "groups" then 
				xml_item.attr[k] = v;
			else
				for i = 1,#v do
					xml_item:tag("group"):text(v[i]):up();
				end
			end
		end
		return xml_item;
	end

	local function item_xml2lua(xml_item)
		local item_table = { };
		local groups = {};
		item_table.groups = groups;
		local jid = xml_item.attr.jid;

		for k, v in pairs(xml_item.attr) do
			if k ~= "xmlns" then
				item_table[k] = v
			end
		end

		for group in xml_item:childtags("group") do
			t_insert(groups, group:get_text())
		end
		return item_table;
	end

	-- should this be add_contact(item, callback) instead?
	function roster:add_contact(jid, nick, groups, callback)
		local item = { jid = jid, name = nick, groups = groups };
		local stanza = verse.iq({ type = "set" })
			:tag("query", { xmlns = xmlns_roster })
				:add_child(item_lua2xml(item));
		stream:send_iq(stanza, function (reply)
			if not callback then return end
			if reply.attr.type == "result" then
				callback(true);
			else
				type, condition, text = reply:get_error();
				callback(nil, { type, condition, text });
			end
		end);
	end
	-- What about subscriptions?

	function roster:delete_contact(jid, callback)
		jid = (type(jid) == "table" and jid.jid) or jid;
		local item = { jid = jid, subscription = "remove" }
		if not roster.items[jid] then return false, "item-not-found"; end
		stream:send_iq(verse.iq({ type = "set" })
			:tag("query", { xmlns = xmlns_roster })
				:add_child(item_lua2xml(item)),
			function (reply)
				if not callback then return end
				if result.attr.type == "result" then
					callback(true);
				else
					type, condition, text = reply:get_error();
					callback(nil, { type, condition, text });
				end
			end);
	end

	local function add_item(item) -- Takes one roster <item/>
		local roster_item = item_xml2lua(item);
		roster.items[roster_item.jid] = roster_item;
	end

	-- Private low level
	local function delete_item(jid)
		local deleted_item = roster.items[jid];
		roster.items[jid] = nil;
		return deleted_item;
	end

	function roster:fetch(callback)
		stream:send_iq(verse.iq({type="get"}):tag("query", { xmlns = xmlns_roster }),
			function (result)
				if result.attr.type == "result" then
					local query = result:get_child("query", xmlns_roster);
					for item in query:childtags("item") do
						add_item(item)
					end
					callback(roster);
				else
					type, condition, text = stanza:get_error();
					callback(nil, { type, condition, text }); --FIXME
				end
			end);
	end

	stream:hook("iq/"..xmlns_roster, function(stanza)
		local type, from = stanza.attr.type, stanza.attr.from;
		if type == "set" and (not from or from == bare_jid(stream.jid)) then
			local query = stanza:get_child("query", xmlns_roster);
			local item = query and query:get_child("item");
			if item then
				local event, target;
				local jid = item.attr.jid;
				if item.attr.subscription == "remove" then
					event = "removed"
					target = delete_item(jid);
				else
					event = roster.items[jid] and "changed" or "added";
					add_item(item)
					target = roster.items[jid];
				end
				if target then
					stream:event("roster/item-"..event, target);
				end
			-- TODO else return error? Events?
			end
			stream:send(verse.reply(stanza))
			return true;
		end
	end);
end
