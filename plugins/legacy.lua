local uuid = require "util.uuid".generate;

local xmlns_auth = "jabber:iq:auth";

function verse.plugins.legacy(stream)
	function handle_auth_form(result)
		local query = result:get_child("query", xmlns_auth);
		if result.attr.type ~= "result" or not query then
			local type, cond, text = result:get_error();
                       stream:debug("warn", "%s %s: %s", type, cond, text);
                       --stream:event("authentication-failure", { condition = cond });
                       -- COMPAT continue anyways
		end
		local auth_data = {
			username = stream.username;
			password = stream.password;
			resource = stream.resource or uuid();
			digest = false, sequence = false, token = false;
		};
		local request = verse.iq({ to = stream.host, type = "set" })
			:tag("query", { xmlns = xmlns_auth });
               if #query > 0 then
		for tag in query:childtags() do
			local field = tag.name;
			local value = auth_data[field];
			if value then
				request:tag(field):text(auth_data[field]):up();
			elseif value == nil then
				local cond = "feature-not-implemented";
				stream:event("authentication-failure", { condition = cond });
				return false;
			end
		end
               else -- COMPAT for servers not following XEP 78
                       for field, value in pairs(auth_data) do
                               if value then
                                       request:tag(field):text(value):up();
                               end
                       end
               end
		stream:send_iq(request, function (response)
			if response.attr.type == "result" then
				stream.resource = auth_data.resource;
				stream.jid = auth_data.username.."@"..stream.host.."/"..auth_data.resource;
				stream:event("authentication-success");
				stream:event("bind-success", stream.jid);
			else
				local type, cond, text = response:get_error();
				stream:event("authentication-failure", { condition = cond });
			end
		end);
	end
	
	function handle_opened(attr)
		if not attr.version then
			stream:send_iq(verse.iq({type="get"})
				:tag("query", { xmlns = "jabber:iq:auth" })
					:tag("username"):text(stream.username),
				handle_auth_form);
				
		end
	end
	stream:hook("opened", handle_opened);
end
