local xmlns_vcard = "vcard-temp";

-- TODO Should this plugin perhaps convert to/from some non-stanza format?
-- {
--	FN = "Kim Alvefur";
--	NICKNAME = "Zash";
-- }

function verse.plugins.vcard(stream)
	function stream:get_vcard(jid, callback) --jid = nil for self
		stream:send_iq(verse.iq({to = jid, type="get"})
			:tag("vCard", {xmlns=xmlns_vcard}), callback);
	end -- FIXME This should pick out the vCard element

	function stream:set_vcard(vCard, callback)
		stream:send_iq(verse.iq({type="set"})
			:tag("vCard", {xmlns=xmlns_vcard})
				:add_child(vCard), callback);
	end
end
