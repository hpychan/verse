local xmlns_vcard, xmlns_vcard_update = "vcard-temp", "vcard-temp:x:update";

-- MMMmmmm.. hacky
local ok, fun = pcall(function() return require("util.hashes").sha1; end);
if not ok then
	ok, fun = pcall(function() return require("util.sha1").sha1; end);
	if not ok then
		error("Could not find a sha1()")
	end
end
local sha1 = fun;

local ok, fun = pcall(function()
	local unb64 = require("util.encodings").base64.decode;
	assert(unb64("SGVsbG8=") == "Hello")
	return unb64;
end);
if not ok then
	ok, fun = pcall(function() return require("mime").unb64; end);
	if not ok then
		error("Could not find a base64 decoder")
	end
end
local unb64 = fun;

function verse.plugins.vcard_update(stream)
	stream:add_plugin("vcard");
	stream:add_plugin("presence");


	local x_vcard_update;

	function update_vcard_photo(vCard) 
		local photo = vCard and vCard:get_child("PHOTO");
		local binval = photo and photo:get_child("BINVAL");
		local data = binval and binval:get_text();
		if data then
			local hash = sha1(unb64(data), true);
			x_vcard_update = verse.stanza("x", { xmlns = xmlns_vcard_update })
				:tag("photo"):text(hash);

			stream:resend_presence()
		else
			x_vcard_update = nil;
		end
	end

	local _set_vcard = stream.set_vcard;

	--[[ TODO Complete this, it's probably broken.
	-- Maybe better to hook outgoing stanza?
	function stream:set_vcard(vCard, callback)
		_set_vcard(vCard, function(event, ...)
			if event.attr.type == "result" then
				local vCard_ = response:get_child("vCard", xmlns_vcard);
				if vCard_ then
					update_vcard_photo(vCard_);
				end -- Or fetch it again? Seems wasteful, but if the server overrides stuff? :/
			end
			if callback then
				return callback(event, ...);
			end
		end);
	end
	--]]

	local initial_vcard_fetch_started;
	stream:hook("ready", function(event)
		if initial_vcard_fetch_started then return; end
		initial_vcard_fetch_started = true;
		-- if stream:jid_supports(nil, xmlns_vcard) then TODO this, correctly
		stream:get_vcard(nil, function(response)
			-- FIXME Picking out the vCard element should be done in get_vcard()
			if response.attr.type == "result" then
				local vCard = response:get_child("vCard", xmlns_vcard);
				if vCard then
					update_vcard_photo(vCard);
				end
			end
			stream:event("ready");
		end);
		return true;
	end, 3);

	stream:hook("presence-out", function(presence)
		if x_vcard_update and not presence:get_child("x", xmlns_vcard_update) then
			presence:add_child(x_vcard_update);
		end
	end, 10);

	--[[
	stream:hook("presence", function(presence)
			local x_vcard_update = presence:get_child("x", xmlns_vcard_update);
			local photo_hash = x_vcard_update and x_vcard_update:get_child("photo");
				:get_child("photo"):get_text(hash);
			if x_vcard_update then
				-- TODO Cache peoples avatars here
			end
	end);
	--]]
end
