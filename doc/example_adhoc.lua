-- Change these:
local jid, password = "user@example.com", "secret";

-- This line squishes verse each time you run,
-- handy if you're hacking on Verse itself
--os.execute("squish --minify-level=none");

require "verse" -- Verse main library
require "verse.client" -- XMPP client library

c = verse.new(verse.logger());
c:add_plugin("version");
c:add_plugin("disco");
c:add_plugin("adhoc");

-- Add some hooks for debugging
c:hook("opened", function () print("Stream opened!") end);
c:hook("closed", function () print("Stream closed!") end);
c:hook("stanza", function (stanza) print("Stanza:", stanza) end);

-- This one prints all received data
c:hook("incoming-raw", print, 1000);

-- Print a message after authentication
c:hook("authentication-success", function () print("Logged in!"); end);
c:hook("authentication-failure", function (err) print("Failed to log in! Error: "..tostring(err.condition)); end);

-- Print a message and exit when disconnected
c:hook("disconnected", function () print("Disconnected!"); os.exit(); end);

-- Now, actually start the connection:
c:connect_client(jid, password);

-- Catch the "ready" event to know when the stream is ready to use
c:hook("ready", function ()
	print("Stream ready!");
	c.version:set{ name = "verse example client" };
	
	local function random_handler()
		return { info = tostring(math.random(1,100)), status = "completed" };
	end
	
	c:add_adhoc_command("Get random number", "random", random_handler);
	
	c:send(verse.presence():add_child(c:caps()));
end);

print("Starting loop...")
verse.loop()
