local xmlns_sm = "urn:xmpp:sm:2";

function verse.plugins.smacks(stream)
	-- State for outgoing stanzas
	local outgoing_queue = {};
	local last_ack = 0;
	
	-- State for incoming stanzas
	local handled_stanza_count = 0;
	
	-- Catch incoming stanzas
	local function incoming_stanza(stanza)
		if stanza.attr.xmlns == "jabber:client" or not stanza.attr.xmlns then
			handled_stanza_count = handled_stanza_count + 1;
			stream:debug("Increasing handled stanzas to %d for %s", handled_stanza_count, stanza:top_tag());
		end
	end
	
	local function on_disconnect()
		stream:debug("smacks: connection lost");
		stream.stream_management_supported = nil;
		if stream.resumption_token then
			stream:debug("smacks: have resumption token, reconnecting in 1s...");
			stream.authenticated = nil;
			verse.add_task(1, function ()
				stream:connect(stream.connect_host or stream.host, stream.connect_port or 5222);
			end);
			return true;
		end
	end	
	
	local function handle_sm_command(stanza)
		if stanza.name == "r" then -- Request for acks for stanzas we received
			stream:debug("Ack requested... acking %d handled stanzas", handled_stanza_count);
			stream:send(verse.stanza("a", { xmlns = xmlns_sm, h = tostring(handled_stanza_count) }));
		elseif stanza.name == "a" then -- Ack for stanzas we sent
			local new_ack = tonumber(stanza.attr.h);
			if new_ack > last_ack then
				local old_unacked = #outgoing_queue;
				for i=last_ack+1,new_ack do
					table.remove(outgoing_queue, 1);
				end
				stream:debug("Received ack: New ack: "..new_ack.." Last ack: "..last_ack.." Unacked stanzas now: "..#outgoing_queue.." (was "..old_unacked..")");
				last_ack = new_ack;
			else
				stream:warn("Received bad ack for "..new_ack.." when last ack was "..last_ack);
			end
		elseif stanza.name == "enabled" then
			stream.smacks = true;
			-- Catch outgoing stanzas
			local old_send = stream.send;
			function stream.send(stream, stanza)
				stream:warn("SENDING");
				if not stanza.attr.xmlns then
					outgoing_queue[#outgoing_queue+1] = stanza;
					local ret = old_send(stream, stanza);
					old_send(stream, verse.stanza("r", { xmlns = xmlns_sm }));
					return ret;
				end
				return old_send(stream, stanza);
			end
			-- Catch incoming stanzas
			stream:hook("stanza", incoming_stanza);
			
			if stanza.attr.id then
				stream.resumption_token = stanza.attr.id;
				stream:hook("disconnected", on_disconnect, 100);
			end
		elseif stanza.name == "resumed" then
			--TODO: Check h of the resumed element, discard any acked stanzas from
			--      our queue (to prevent duplicates), then re-send any lost stanzas.
			stream:debug("Resumed successfully");
			stream:event("resumed");
		else
			stream:warn("Don't know how to handle "..xmlns_sm.."/"..stanza.name);
		end
	end

	local function on_bind_success()
		if not stream.smacks then
			--stream:unhook("bind-success", on_bind_success);
			stream:debug("smacks: sending enable");
			stream:send(verse.stanza("enable", { xmlns = xmlns_sm, resume = "true" }));
		end
	end

	local function on_features(features)
		if features:get_child("sm", xmlns_sm) then
			stream.stream_management_supported = true;
			if stream.smacks and stream.bound then -- Already enabled in a previous session - resume
				stream:debug("Resuming stream with %d handled stanzas", handled_stanza_count);
				stream:send(verse.stanza("resume", { xmlns = xmlns_sm,
					h = handled_stanza_count, previd = stream.resumption_token }));
				return true;
			else
				stream:hook("bind-success", on_bind_success, 1);
			end
		end
	end

	stream:hook("stream-features", on_features, 250);
	stream:hook("stream/"..xmlns_sm, handle_sm_command);
	--stream:hook("ready", on_stream_ready, 500);
end
