-- Implements XEP-0049: Private XML Storage

local xmlns_private = "jabber:iq:private";

function verse.plugins.private(stream)
	function stream:private_set(name, xmlns, data, callback)
		local iq = verse.iq({ type = "set" })
			:tag("query", { xmlns = xmlns_private });
		if data then
			if data.name == name and data.attr and data.attr.xmlns == xmlns then
				iq:add_child(data);
			else
				iq:tag(name, { xmlns = xmlns })
					:add_child(data);
			end
		end
		self:send_iq(iq, callback);
	end
	
	function stream:private_get(name, xmlns, callback)
		self:send_iq(verse.iq({type="get"})
			:tag("query", { xmlns = xmlns_private })
				:tag(name, { xmlns = xmlns }),
			function (reply)
				if reply.attr.type == "result" then
					local query = reply:get_child("query", xmlns_private);
					local result = query:get_child(name, xmlns);
					callback(result);
				end
			end);
	end
end

