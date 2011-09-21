local xmlns_last = "jabber:iq:last";

local function set_uptime(self, uptime_info)
	self.starttime = uptime_info.starttime;
end

function verse.plugins.uptime(stream)
	stream.uptime = { set = set_uptime };
	stream:hook("iq/"..xmlns_last, function (stanza)
		if stanza.attr.type ~= "get" then return; end
		local reply = verse.reply(stanza)
			:tag("query", { seconds = tostring(os.difftime(os.time(), stream.uptime.starttime)), xmlns = xmlns_last });
		stream:send(reply);
		return true;
	end);

	function stream:query_uptime(target_jid, callback)
		callback = callback or function (uptime) return stream:event("uptime/response", uptime); end
		stream:send_iq(verse.iq({ type = "get", to = target_jid })
			:tag("query", { xmlns = xmlns_last }),
			function (reply)
				local query = reply:get_child("query", xmlns_last);
				if reply.attr.type == "result" then
					local seconds = query.attr.seconds;
					callback({
						seconds = seconds or nil;
						});
				else
					local type, condition, text = reply:get_error();
					callback({
						error = true;
						condition = condition;
						text = text;
						type = type;
						});
				end
			end);
	end
	return true;
end
