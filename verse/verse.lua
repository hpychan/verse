package.preload['util.encodings'] = (function (...)
local function not_impl()
	error("Function not implemented");
end

local mime = require "mime";

module "encodings"

stringprep = {};
base64 = { encode = mime.b64, decode = not_impl }; --mime.unb64 is buggy with \0

return _M;
 end)
package.preload['util.hashes'] = (function (...)
local sha1 = require "util.sha1";

return { sha1 = sha1.sha1 };
 end)
package.preload['util.logger'] = (function (...)
local select, tostring = select, tostring;
local io_write = io.write;
module "logger"

local function format(format, ...)
	local n, maxn = 0, #arg;
	return (format:gsub("%%(.)", function (c) if c ~= "%" and n <= maxn then n = n + 1; return tostring(arg[n]); end end));
end

local function format(format, ...)
	local n, maxn = 0, select('#', ...);
	local arg = { ... };
	return (format:gsub("%%(.)", function (c) if n <= maxn then n = n + 1; return tostring(arg[n]); end end));
end

function init(name)
	return function (level, message, ...)
		io_write(level, "\t", format(message, ...), "\n");
	end
end

return _M;
 end)
package.preload['util.sha1'] = (function (...)
-------------------------------------------------
---      *** SHA-1 algorithm for Lua ***      ---
-------------------------------------------------
--- Author:  Martin Huesser                   ---
--- Date:    2008-06-16                       ---
--- License: You may use this code in your    ---
---          projects as long as this header  ---
---          stays intact.                    ---
-------------------------------------------------

local strlen  = string.len
local strchar = string.char
local strbyte = string.byte
local strsub  = string.sub
local floor   = math.floor
local bit     = require "bit"
local bnot    = bit.bnot
local band    = bit.band
local bor     = bit.bor
local bxor    = bit.bxor
local shl     = bit.lshift
local shr     = bit.rshift
local h0, h1, h2, h3, h4

-------------------------------------------------

local function LeftRotate(val, nr)
	return shl(val, nr) + shr(val, 32 - nr)
end

-------------------------------------------------

local function ToHex(num)
	local i, d
	local str = ""
	for i = 1, 8 do
		d = band(num, 15)
		if (d < 10) then
			str = strchar(d + 48) .. str
		else
			str = strchar(d + 87) .. str
		end
		num = floor(num / 16)
	end
	return str
end

-------------------------------------------------

local function PreProcess(str)
	local bitlen, i
	local str2 = ""
	bitlen = strlen(str) * 8
	str = str .. strchar(128)
	i = 56 - band(strlen(str), 63)
	if (i < 0) then
		i = i + 64
	end
	for i = 1, i do
		str = str .. strchar(0)
	end
	for i = 1, 8 do
		str2 = strchar(band(bitlen, 255)) .. str2
		bitlen = floor(bitlen / 256)
	end
	return str .. str2
end

-------------------------------------------------

local function MainLoop(str)
	local a, b, c, d, e, f, k, t
	local i, j
	local w = {}
	while (str ~= "") do
		for i = 0, 15 do
			w[i] = 0
			for j = 1, 4 do
				w[i] = w[i] * 256 + strbyte(str, i * 4 + j)
			end
		end
		for i = 16, 79 do
			w[i] = LeftRotate(bxor(bxor(w[i - 3], w[i - 8]), bxor(w[i - 14], w[i - 16])), 1)
		end
		a = h0
		b = h1
		c = h2
		d = h3
		e = h4
		for i = 0, 79 do
			if (i < 20) then
				f = bor(band(b, c), band(bnot(b), d))
				k = 1518500249
			elseif (i < 40) then
				f = bxor(bxor(b, c), d)
				k = 1859775393
			elseif (i < 60) then
				f = bor(bor(band(b, c), band(b, d)), band(c, d))
				k = 2400959708
			else
				f = bxor(bxor(b, c), d)
				k = 3395469782
			end
			t = LeftRotate(a, 5) + f + e + k + w[i]	
			e = d
			d = c
			c = LeftRotate(b, 30)
			b = a
			a = t
		end
		h0 = band(h0 + a, 4294967295)
		h1 = band(h1 + b, 4294967295)
		h2 = band(h2 + c, 4294967295)
		h3 = band(h3 + d, 4294967295)
		h4 = band(h4 + e, 4294967295)
		str = strsub(str, 65)
	end
end

-------------------------------------------------

local function sha1(str, hexres)
	str = PreProcess(str)
	h0  = 1732584193
	h1  = 4023233417
	h2  = 2562383102
	h3  = 0271733878
	h4  = 3285377520
	MainLoop(str)
	local hex = ToHex(h0)..ToHex(h1)..ToHex(h2)
	            ..ToHex(h3)..ToHex(h4);
	if hexres then
		return  hex;
	else
		return (hex:gsub("..", function (byte)
			return string.char(tonumber(byte, 16));
		end));
	end
end

_G.sha1 = {sha1 = sha1};
return _G.sha1;

-------------------------------------------------
-------------------------------------------------
-------------------------------------------------
 end)
package.preload['lib.adhoc'] = (function (...)
-- Copyright (C) 2009-2010 Florian Zeitz
--
-- This file is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local st, uuid = require "util.stanza", require "util.uuid";

local xmlns_cmd = "http://jabber.org/protocol/commands";

local states = {}

local _M = {};

function _cmdtag(desc, status, sessionid, action)
	local cmd = st.stanza("command", { xmlns = xmlns_cmd, node = desc.node, status = status });
	if sessionid then cmd.attr.sessionid = sessionid; end
	if action then cmd.attr.action = action; end

	return cmd;
end

function _M.new(name, node, handler, permission)
	return { name = name, node = node, handler = handler, cmdtag = _cmdtag, permission = (permission or "user") };
end

function _M.handle_cmd(command, origin, stanza)
	local sessionid = stanza.tags[1].attr.sessionid or uuid.generate();
	local dataIn = {};
	dataIn.to = stanza.attr.to;
	dataIn.from = stanza.attr.from;
	dataIn.action = stanza.tags[1].attr.action or "execute";
	dataIn.form = stanza.tags[1]:child_with_ns("jabber:x:data");

	local data, state = command:handler(dataIn, states[sessionid]);
	states[sessionid] = state;
	local stanza = st.reply(stanza);
	if data.status == "completed" then
		states[sessionid] = nil;
		cmdtag = command:cmdtag("completed", sessionid);
	elseif data.status == "canceled" then
		states[sessionid] = nil;
		cmdtag = command:cmdtag("canceled", sessionid);
	elseif data.status == "error" then
		states[sessionid] = nil;
		stanza = st.error_reply(stanza, data.error.type, data.error.condition, data.error.message);
		origin.send(stanza);
		return true;
	else
		cmdtag = command:cmdtag("executing", sessionid);
	end

	for name, content in pairs(data) do
		if name == "info" then
			cmdtag:tag("note", {type="info"}):text(content):up();
		elseif name == "warn" then
			cmdtag:tag("note", {type="warn"}):text(content):up();
		elseif name == "error" then
			cmdtag:tag("note", {type="error"}):text(content.message):up();
		elseif name =="actions" then
			local actions = st.stanza("actions");
			for _, action in ipairs(content) do
				if (action == "prev") or (action == "next") or (action == "complete") then
					actions:tag(action):up();
				else
					module:log("error", 'Command "'..command.name..
						'" at node "'..command.node..'" provided an invalid action "'..action..'"');
				end
			end
			cmdtag:add_child(actions);
		elseif name == "form" then
			cmdtag:add_child((content.layout or content):form(content.values));
		elseif name == "result" then
			cmdtag:add_child((content.layout or content):form(content.values, "result"));
		elseif name == "other" then
			cmdtag:add_child(content);
		end
	end
	stanza:add_child(cmdtag);
	origin.send(stanza);

	return true;
end

return _M;
 end)
package.preload['util.stanza'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--


local t_insert      =  table.insert;
local t_concat      =  table.concat;
local t_remove      =  table.remove;
local t_concat      =  table.concat;
local s_format      = string.format;
local s_match       =  string.match;
local tostring      =      tostring;
local setmetatable  =  setmetatable;
local getmetatable  =  getmetatable;
local pairs         =         pairs;
local ipairs        =        ipairs;
local type          =          type;
local next          =          next;
local print         =         print;
local unpack        =        unpack;
local s_gsub        =   string.gsub;
local s_char        =   string.char;
local s_find        =   string.find;
local os            =            os;

local do_pretty_printing = not os.getenv("WINDIR");
local getstyle, getstring;
if do_pretty_printing then
	local ok, termcolours = pcall(require, "util.termcolours");
	if ok then
		getstyle, getstring = termcolours.getstyle, termcolours.getstring;
	else
		do_pretty_printing = nil;
	end
end

local xmlns_stanzas = "urn:ietf:params:xml:ns:xmpp-stanzas";

module "stanza"

stanza_mt = { __type = "stanza" };
stanza_mt.__index = stanza_mt;
local stanza_mt = stanza_mt;

function stanza(name, attr)
	local stanza = { name = name, attr = attr or {}, tags = {} };
	return setmetatable(stanza, stanza_mt);
end
local stanza = stanza;

function stanza_mt:query(xmlns)
	return self:tag("query", { xmlns = xmlns });
end

function stanza_mt:body(text, attr)
	return self:tag("body", attr):text(text);
end

function stanza_mt:tag(name, attrs)
	local s = stanza(name, attrs);
	local last_add = self.last_add;
	if not last_add then last_add = {}; self.last_add = last_add; end
	(last_add[#last_add] or self):add_direct_child(s);
	t_insert(last_add, s);
	return self;
end

function stanza_mt:text(text)
	local last_add = self.last_add;
	(last_add and last_add[#last_add] or self):add_direct_child(text);
	return self;
end

function stanza_mt:up()
	local last_add = self.last_add;
	if last_add then t_remove(last_add); end
	return self;
end

function stanza_mt:reset()
	self.last_add = nil;
	return self;
end

function stanza_mt:add_direct_child(child)
	if type(child) == "table" then
		t_insert(self.tags, child);
	end
	t_insert(self, child);
end

function stanza_mt:add_child(child)
	local last_add = self.last_add;
	(last_add and last_add[#last_add] or self):add_direct_child(child);
	return self;
end

function stanza_mt:get_child(name, xmlns)
	for _, child in ipairs(self.tags) do
		if (not name or child.name == name)
			and ((not xmlns and self.attr.xmlns == child.attr.xmlns)
				or child.attr.xmlns == xmlns) then
			
			return child;
		end
	end
end

function stanza_mt:get_child_text(name, xmlns)
	local tag = self:get_child(name, xmlns);
	if tag then
		return tag:get_text();
	end
	return nil;
end

function stanza_mt:child_with_name(name)
	for _, child in ipairs(self.tags) do
		if child.name == name then return child; end
	end
end

function stanza_mt:child_with_ns(ns)
	for _, child in ipairs(self.tags) do
		if child.attr.xmlns == ns then return child; end
	end
end

function stanza_mt:children()
	local i = 0;
	return function (a)
			i = i + 1
			return a[i];
		end, self, i;
end

function stanza_mt:childtags(name, xmlns)
	xmlns = xmlns or self.attr.xmlns;
	local tags = self.tags;
	local start_i, max_i = 1, #tags;
	return function ()
		for i = start_i, max_i do
			local v = tags[i];
			if (not name or v.name == name)
			and (not xmlns or xmlns == v.attr.xmlns) then
				start_i = i+1;
				return v;
			end
		end
	end;
end

function stanza_mt:maptags(callback)
	local tags, curr_tag = self.tags, 1;
	local n_children, n_tags = #self, #tags;
	
	local i = 1;
	while curr_tag <= n_tags do
		if self[i] == tags[curr_tag] then
			local ret = callback(self[i]);
			if ret == nil then
				t_remove(self, i);
				t_remove(tags, curr_tag);
				n_children = n_children - 1;
				n_tags = n_tags - 1;
			else
				self[i] = ret;
				tags[i] = ret;
			end
			i = i + 1;
			curr_tag = curr_tag + 1;
		end
	end
	return self;
end

local xml_escape
do
	local escape_table = { ["'"] = "&apos;", ["\""] = "&quot;", ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" };
	function xml_escape(str) return (s_gsub(str, "['&<>\"]", escape_table)); end
	_M.xml_escape = xml_escape;
end

local function _dostring(t, buf, self, xml_escape, parentns)
	local nsid = 0;
	local name = t.name
	t_insert(buf, "<"..name);
	for k, v in pairs(t.attr) do
		if s_find(k, "\1", 1, true) then
			local ns, attrk = s_match(k, "^([^\1]*)\1?(.*)$");
			nsid = nsid + 1;
			t_insert(buf, " xmlns:ns"..nsid.."='"..xml_escape(ns).."' ".."ns"..nsid..":"..attrk.."='"..xml_escape(v).."'");
		elseif not(k == "xmlns" and v == parentns) then
			t_insert(buf, " "..k.."='"..xml_escape(v).."'");
		end
	end
	local len = #t;
	if len == 0 then
		t_insert(buf, "/>");
	else
		t_insert(buf, ">");
		for n=1,len do
			local child = t[n];
			if child.name then
				self(child, buf, self, xml_escape, t.attr.xmlns);
			else
				t_insert(buf, xml_escape(child));
			end
		end
		t_insert(buf, "</"..name..">");
	end
end
function stanza_mt.__tostring(t)
	local buf = {};
	_dostring(t, buf, _dostring, xml_escape, nil);
	return t_concat(buf);
end

function stanza_mt.top_tag(t)
	local attr_string = "";
	if t.attr then
		for k, v in pairs(t.attr) do if type(k) == "string" then attr_string = attr_string .. s_format(" %s='%s'", k, xml_escape(tostring(v))); end end
	end
	return s_format("<%s%s>", t.name, attr_string);
end

function stanza_mt.get_text(t)
	if #t.tags == 0 then
		return t_concat(t);
	end
end

function stanza_mt.get_error(stanza)
	local type, condition, text;
	
	local error_tag = stanza:get_child("error");
	if not error_tag then
		return nil, nil, nil;
	end
	type = error_tag.attr.type;
	
	for child in error_tag:childtags() do
		if child.attr.xmlns == xmlns_stanzas then
			if not text and child.name == "text" then
				text = child:get_text();
			elseif not condition then
				condition = child.name;
			end
			if condition and text then
				break;
			end
		end
	end
	return type, condition or "undefined-condition", text;
end

function stanza_mt.__add(s1, s2)
	return s1:add_direct_child(s2);
end


do
	local id = 0;
	function new_id()
		id = id + 1;
		return "lx"..id;
	end
end

function preserialize(stanza)
	local s = { name = stanza.name, attr = stanza.attr };
	for _, child in ipairs(stanza) do
		if type(child) == "table" then
			t_insert(s, preserialize(child));
		else
			t_insert(s, child);
		end
	end
	return s;
end

function deserialize(stanza)
	-- Set metatable
	if stanza then
		local attr = stanza.attr;
		for i=1,#attr do attr[i] = nil; end
		local attrx = {};
		for att in pairs(attr) do
			if s_find(att, "|", 1, true) and not s_find(att, "\1", 1, true) then
				local ns,na = s_match(att, "^([^|]+)|(.+)$");
				attrx[ns.."\1"..na] = attr[att];
				attr[att] = nil;
			end
		end
		for a,v in pairs(attrx) do
			attr[a] = v;
		end
		setmetatable(stanza, stanza_mt);
		for _, child in ipairs(stanza) do
			if type(child) == "table" then
				deserialize(child);
			end
		end
		if not stanza.tags then
			-- Rebuild tags
			local tags = {};
			for _, child in ipairs(stanza) do
				if type(child) == "table" then
					t_insert(tags, child);
				end
			end
			stanza.tags = tags;
		end
	end
	
	return stanza;
end

local function _clone(stanza)
	local attr, tags = {}, {};
	for k,v in pairs(stanza.attr) do attr[k] = v; end
	local new = { name = stanza.name, attr = attr, tags = tags };
	for i=1,#stanza do
		local child = stanza[i];
		if child.name then
			child = _clone(child);
			t_insert(tags, child);
		end
		t_insert(new, child);
	end
	return setmetatable(new, stanza_mt);
end
clone = _clone;

function message(attr, body)
	if not body then
		return stanza("message", attr);
	else
		return stanza("message", attr):tag("body"):text(body):up();
	end
end
function iq(attr)
	if attr and not attr.id then attr.id = new_id(); end
	return stanza("iq", attr or { id = new_id() });
end

function reply(orig)
	return stanza(orig.name, orig.attr and { to = orig.attr.from, from = orig.attr.to, id = orig.attr.id, type = ((orig.name == "iq" and "result") or orig.attr.type) });
end

do
	local xmpp_stanzas_attr = { xmlns = xmlns_stanzas };
	function error_reply(orig, type, condition, message)
		local t = reply(orig);
		t.attr.type = "error";
		t:tag("error", {type = type}) --COMPAT: Some day xmlns:stanzas goes here
			:tag(condition, xmpp_stanzas_attr):up();
		if (message) then t:tag("text", xmpp_stanzas_attr):text(message):up(); end
		return t; -- stanza ready for adding app-specific errors
	end
end

function presence(attr)
	return stanza("presence", attr);
end

if do_pretty_printing then
	local style_attrk = getstyle("yellow");
	local style_attrv = getstyle("red");
	local style_tagname = getstyle("red");
	local style_punc = getstyle("magenta");
	
	local attr_format = " "..getstring(style_attrk, "%s")..getstring(style_punc, "=")..getstring(style_attrv, "'%s'");
	local top_tag_format = getstring(style_punc, "<")..getstring(style_tagname, "%s").."%s"..getstring(style_punc, ">");
	--local tag_format = getstring(style_punc, "<")..getstring(style_tagname, "%s").."%s"..getstring(style_punc, ">").."%s"..getstring(style_punc, "</")..getstring(style_tagname, "%s")..getstring(style_punc, ">");
	local tag_format = top_tag_format.."%s"..getstring(style_punc, "</")..getstring(style_tagname, "%s")..getstring(style_punc, ">");
	function stanza_mt.pretty_print(t)
		local children_text = "";
		for n, child in ipairs(t) do
			if type(child) == "string" then
				children_text = children_text .. xml_escape(child);
			else
				children_text = children_text .. child:pretty_print();
			end
		end

		local attr_string = "";
		if t.attr then
			for k, v in pairs(t.attr) do if type(k) == "string" then attr_string = attr_string .. s_format(attr_format, k, tostring(v)); end end
		end
		return s_format(tag_format, t.name, attr_string, children_text, t.name);
	end
	
	function stanza_mt.pretty_top_tag(t)
		local attr_string = "";
		if t.attr then
			for k, v in pairs(t.attr) do if type(k) == "string" then attr_string = attr_string .. s_format(attr_format, k, tostring(v)); end end
		end
		return s_format(top_tag_format, t.name, attr_string);
	end
else
	-- Sorry, fresh out of colours for you guys ;)
	stanza_mt.pretty_print = stanza_mt.__tostring;
	stanza_mt.pretty_top_tag = stanza_mt.top_tag;
end

return _M;
 end)
package.preload['util.timer'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--


local ns_addtimer = require "net.server".addtimer;
local event = require "net.server".event;
local event_base = require "net.server".event_base;

local math_min = math.min
local math_huge = math.huge
local get_time = require "socket".gettime;
local t_insert = table.insert;
local t_remove = table.remove;
local ipairs, pairs = ipairs, pairs;
local type = type;

local data = {};
local new_data = {};

module "timer"

local _add_task;
if not event then
	function _add_task(delay, func)
		local current_time = get_time();
		delay = delay + current_time;
		if delay >= current_time then
			t_insert(new_data, {delay, func});
		else
			func();
		end
	end

	ns_addtimer(function()
		local current_time = get_time();
		if #new_data > 0 then
			for _, d in pairs(new_data) do
				t_insert(data, d);
			end
			new_data = {};
		end
		
		local next_time = math_huge;
		for i, d in pairs(data) do
			local t, func = d[1], d[2];
			if t <= current_time then
				data[i] = nil;
				local r = func(current_time);
				if type(r) == "number" then
					_add_task(r, func);
					next_time = math_min(next_time, r);
				end
			else
				next_time = math_min(next_time, t - current_time);
			end
		end
		return next_time;
	end);
else
	local EVENT_LEAVE = (event.core and event.core.LEAVE) or -1;
	function _add_task(delay, func)
		local event_handle;
		event_handle = event_base:addevent(nil, 0, function ()
			local ret = func();
			if ret then
				return 0, ret;
			elseif event_handle then
				return EVENT_LEAVE;
			end
		end
		, delay);
	end
end

add_task = _add_task;

return _M;
 end)
package.preload['util.termcolours'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--


local t_concat, t_insert = table.concat, table.insert;
local char, format = string.char, string.format;
local ipairs = ipairs;
local io_write = io.write;

local windows;
if os.getenv("WINDIR") then
	windows = require "util.windows";
end
local orig_color = windows and windows.get_consolecolor and windows.get_consolecolor();

module "termcolours"

local stylemap = {
			reset = 0; bright = 1, dim = 2, underscore = 4, blink = 5, reverse = 7, hidden = 8;
			black = 30; red = 31; green = 32; yellow = 33; blue = 34; magenta = 35; cyan = 36; white = 37;
			["black background"] = 40; ["red background"] = 41; ["green background"] = 42; ["yellow background"] = 43; ["blue background"] = 44; ["magenta background"] = 45; ["cyan background"] = 46; ["white background"] = 47;
			bold = 1, dark = 2, underline = 4, underlined = 4, normal = 0;
		}

local winstylemap = {
	["0"] = orig_color, -- reset
	["1"] = 7+8, -- bold
	["1;33"] = 2+4+8, -- bold yellow
	["1;31"] = 4+8 -- bold red
}

local fmt_string = char(0x1B).."[%sm%s"..char(0x1B).."[0m";
function getstring(style, text)
	if style then
		return format(fmt_string, style, text);
	else
		return text;
	end
end

function getstyle(...)
	local styles, result = { ... }, {};
	for i, style in ipairs(styles) do
		style = stylemap[style];
		if style then
			t_insert(result, style);
		end
	end
	return t_concat(result, ";");
end

local last = "0";
function setstyle(style)
	style = style or "0";
	if style ~= last then
		io_write("\27["..style.."m");
		last = style;
	end
end

if windows then
	function setstyle(style)
		style = style or "0";
		if style ~= last then
			windows.set_consolecolor(winstylemap[style] or orig_color);
			last = style;
		end
	end
	if not orig_color then
		function setstyle(style) end
	end
end

return _M;
 end)
package.preload['util.uuid'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--


local m_random = math.random;
local tostring = tostring;
local os_time = os.time;
local os_clock = os.clock;
local sha1 = require "util.hashes".sha1;

module "uuid"

local last_uniq_time = 0;
local function uniq_time()
	local new_uniq_time = os_time();
	if last_uniq_time >= new_uniq_time then new_uniq_time = last_uniq_time + 1; end
	last_uniq_time = new_uniq_time;
	return new_uniq_time;
end

local function new_random(x)
	return sha1(x..os_clock()..tostring({}), true);
end

local buffer = new_random(uniq_time());
local function _seed(x)
	buffer = new_random(buffer..x);
end
local function get_nibbles(n)
	if #buffer < n then _seed(uniq_time()); end
	local r = buffer:sub(0, n);
	buffer = buffer:sub(n+1);
	return r;
end
local function get_twobits()
	return ("%x"):format(get_nibbles(1):byte() % 4 + 8);
end

function generate()
	-- generate RFC 4122 complaint UUIDs (version 4 - random)
	return get_nibbles(8).."-"..get_nibbles(4).."-4"..get_nibbles(3).."-"..(get_twobits())..get_nibbles(3).."-"..get_nibbles(12);
end
seed = _seed;

return _M;
 end)
package.preload['net.dns'] = (function (...)
-- Prosody IM
-- This file is included with Prosody IM. It has modifications,
-- which are hereby placed in the public domain.


-- todo: quick (default) header generation
-- todo: nxdomain, error handling
-- todo: cache results of encodeName


-- reference: http://tools.ietf.org/html/rfc1035
-- reference: http://tools.ietf.org/html/rfc1876 (LOC)


local socket = require "socket";
local timer = require "util.timer";

local _, windows = pcall(require, "util.windows");
local is_windows = (_ and windows) or os.getenv("WINDIR");

local coroutine, io, math, string, table =
      coroutine, io, math, string, table;

local ipairs, next, pairs, print, setmetatable, tostring, assert, error, unpack, select, type=
      ipairs, next, pairs, print, setmetatable, tostring, assert, error, unpack, select, type;

local ztact = { -- public domain 20080404 lua@ztact.com
	get = function(parent, ...)
		local len = select('#', ...);
		for i=1,len do
			parent = parent[select(i, ...)];
			if parent == nil then break; end
		end
		return parent;
	end;
	set = function(parent, ...)
		local len = select('#', ...);
		local key, value = select(len-1, ...);
		local cutpoint, cutkey;

		for i=1,len-2 do
			local key = select (i, ...)
			local child = parent[key]

			if value == nil then
				if child == nil then
					return;
				elseif next(child, next(child)) then
					cutpoint = nil; cutkey = nil;
				elseif cutpoint == nil then
					cutpoint = parent; cutkey = key;
				end
			elseif child == nil then
				child = {};
				parent[key] = child;
			end
			parent = child
		end

		if value == nil and cutpoint then
			cutpoint[cutkey] = nil;
		else
			parent[key] = value;
			return value;
		end
	end;
};
local get, set = ztact.get, ztact.set;

local default_timeout = 15;

-------------------------------------------------- module dns
module('dns')
local dns = _M;


-- dns type & class codes ------------------------------ dns type & class codes


local append = table.insert


local function highbyte(i)    -- - - - - - - - - - - - - - - - - - -  highbyte
	return (i-(i%0x100))/0x100;
end


local function augment (t)    -- - - - - - - - - - - - - - - - - - - -  augment
	local a = {};
	for i,s in pairs(t) do
		a[i] = s;
		a[s] = s;
		a[string.lower(s)] = s;
	end
	return a;
end


local function encode (t)    -- - - - - - - - - - - - - - - - - - - - -  encode
	local code = {};
	for i,s in pairs(t) do
		local word = string.char(highbyte(i), i%0x100);
		code[i] = word;
		code[s] = word;
		code[string.lower(s)] = word;
	end
	return code;
end


dns.types = {
	'A', 'NS', 'MD', 'MF', 'CNAME', 'SOA', 'MB', 'MG', 'MR', 'NULL', 'WKS',
	'PTR', 'HINFO', 'MINFO', 'MX', 'TXT',
	[ 28] = 'AAAA', [ 29] = 'LOC',   [ 33] = 'SRV',
	[252] = 'AXFR', [253] = 'MAILB', [254] = 'MAILA', [255] = '*' };


dns.classes = { 'IN', 'CS', 'CH', 'HS', [255] = '*' };


dns.type      = augment (dns.types);
dns.class     = augment (dns.classes);
dns.typecode  = encode  (dns.types);
dns.classcode = encode  (dns.classes);



local function standardize(qname, qtype, qclass)    -- - - - - - - standardize
	if string.byte(qname, -1) ~= 0x2E then qname = qname..'.';  end
	qname = string.lower(qname);
	return qname, dns.type[qtype or 'A'], dns.class[qclass or 'IN'];
end


local function prune(rrs, time, soft)    -- - - - - - - - - - - - - - -  prune
	time = time or socket.gettime();
	for i,rr in pairs(rrs) do
		if rr.tod then
			-- rr.tod = rr.tod - 50    -- accelerated decripitude
			rr.ttl = math.floor(rr.tod - time);
			if rr.ttl <= 0 then
				table.remove(rrs, i);
				return prune(rrs, time, soft); -- Re-iterate
			end
		elseif soft == 'soft' then    -- What is this?  I forget!
			assert(rr.ttl == 0);
			rrs[i] = nil;
		end
	end
end


-- metatables & co. ------------------------------------------ metatables & co.


local resolver = {};
resolver.__index = resolver;

resolver.timeout = default_timeout;

local function default_rr_tostring(rr)
	local rr_val = rr.type and rr[rr.type:lower()];
	if type(rr_val) ~= "string" then
		return "<UNKNOWN RDATA TYPE>";
	end
	return rr_val;
end

local special_tostrings = {
	LOC = resolver.LOC_tostring;
	MX  = function (rr)
		return string.format('%2i %s', rr.pref, rr.mx);
	end;
	SRV = function (rr)
		local s = rr.srv;
		return string.format('%5d %5d %5d %s', s.priority, s.weight, s.port, s.target);
	end;
};

local rr_metatable = {};   -- - - - - - - - - - - - - - - - - - -  rr_metatable
function rr_metatable.__tostring(rr)
	local rr_string = (special_tostrings[rr.type] or default_rr_tostring)(rr);
	return string.format('%2s %-5s %6i %-28s %s', rr.class, rr.type, rr.ttl, rr.name, rr_string);
end


local rrs_metatable = {};    -- - - - - - - - - - - - - - - - - -  rrs_metatable
function rrs_metatable.__tostring(rrs)
	local t = {};
	for i,rr in pairs(rrs) do
		append(t, tostring(rr)..'\n');
	end
	return table.concat(t);
end


local cache_metatable = {};    -- - - - - - - - - - - - - - - -  cache_metatable
function cache_metatable.__tostring(cache)
	local time = socket.gettime();
	local t = {};
	for class,types in pairs(cache) do
		for type,names in pairs(types) do
			for name,rrs in pairs(names) do
				prune(rrs, time);
				append(t, tostring(rrs));
			end
		end
	end
	return table.concat(t);
end


function resolver:new()    -- - - - - - - - - - - - - - - - - - - - - resolver
	local r = { active = {}, cache = {}, unsorted = {} };
	setmetatable(r, resolver);
	setmetatable(r.cache, cache_metatable);
	setmetatable(r.unsorted, { __mode = 'kv' });
	return r;
end


-- packet layer -------------------------------------------------- packet layer


function dns.random(...)    -- - - - - - - - - - - - - - - - - - -  dns.random
	math.randomseed(math.floor(10000*socket.gettime()));
	dns.random = math.random;
	return dns.random(...);
end


local function encodeHeader(o)    -- - - - - - - - - - - - - - -  encodeHeader
	o = o or {};
	o.id = o.id or dns.random(0, 0xffff); -- 16b	(random) id

	o.rd = o.rd or 1;		--  1b  1 recursion desired
	o.tc = o.tc or 0;		--  1b	1 truncated response
	o.aa = o.aa or 0;		--  1b	1 authoritative response
	o.opcode = o.opcode or 0;	--  4b	0 query
				--  1 inverse query
				--	2 server status request
				--	3-15 reserved
	o.qr = o.qr or 0;		--  1b	0 query, 1 response

	o.rcode = o.rcode or 0;	--  4b  0 no error
				--	1 format error
				--	2 server failure
				--	3 name error
				--	4 not implemented
				--	5 refused
				--	6-15 reserved
	o.z = o.z  or 0;		--  3b  0 resvered
	o.ra = o.ra or 0;		--  1b  1 recursion available

	o.qdcount = o.qdcount or 1;	-- 16b	number of question RRs
	o.ancount = o.ancount or 0;	-- 16b	number of answers RRs
	o.nscount = o.nscount or 0;	-- 16b	number of nameservers RRs
	o.arcount = o.arcount or 0;	-- 16b  number of additional RRs

	-- string.char() rounds, so prevent roundup with -0.4999
	local header = string.char(
		highbyte(o.id), o.id %0x100,
		o.rd + 2*o.tc + 4*o.aa + 8*o.opcode + 128*o.qr,
		o.rcode + 16*o.z + 128*o.ra,
		highbyte(o.qdcount),  o.qdcount %0x100,
		highbyte(o.ancount),  o.ancount %0x100,
		highbyte(o.nscount),  o.nscount %0x100,
		highbyte(o.arcount),  o.arcount %0x100
	);

	return header, o.id;
end


local function encodeName(name)    -- - - - - - - - - - - - - - - - encodeName
	local t = {};
	for part in string.gmatch(name, '[^.]+') do
		append(t, string.char(string.len(part)));
		append(t, part);
	end
	append(t, string.char(0));
	return table.concat(t);
end


local function encodeQuestion(qname, qtype, qclass)    -- - - - encodeQuestion
	qname  = encodeName(qname);
	qtype  = dns.typecode[qtype or 'a'];
	qclass = dns.classcode[qclass or 'in'];
	return qname..qtype..qclass;
end


function resolver:byte(len)    -- - - - - - - - - - - - - - - - - - - - - byte
	len = len or 1;
	local offset = self.offset;
	local last = offset + len - 1;
	if last > #self.packet then
		error(string.format('out of bounds: %i>%i', last, #self.packet));
	end
	self.offset = offset + len;
	return string.byte(self.packet, offset, last);
end


function resolver:word()    -- - - - - - - - - - - - - - - - - - - - - -  word
	local b1, b2 = self:byte(2);
	return 0x100*b1 + b2;
end


function resolver:dword ()    -- - - - - - - - - - - - - - - - - - - - -  dword
	local b1, b2, b3, b4 = self:byte(4);
	--print('dword', b1, b2, b3, b4);
	return 0x1000000*b1 + 0x10000*b2 + 0x100*b3 + b4;
end


function resolver:sub(len)    -- - - - - - - - - - - - - - - - - - - - - - sub
	len = len or 1;
	local s = string.sub(self.packet, self.offset, self.offset + len - 1);
	self.offset = self.offset + len;
	return s;
end


function resolver:header(force)    -- - - - - - - - - - - - - - - - - - header
	local id = self:word();
	--print(string.format(':header  id  %x', id));
	if not self.active[id] and not force then return nil; end

	local h = { id = id };

	local b1, b2 = self:byte(2);

	h.rd      = b1 %2;
	h.tc      = b1 /2%2;
	h.aa      = b1 /4%2;
	h.opcode  = b1 /8%16;
	h.qr      = b1 /128;

	h.rcode   = b2 %16;
	h.z       = b2 /16%8;
	h.ra      = b2 /128;

	h.qdcount = self:word();
	h.ancount = self:word();
	h.nscount = self:word();
	h.arcount = self:word();

	for k,v in pairs(h) do h[k] = v-v%1; end

	return h;
end


function resolver:name()    -- - - - - - - - - - - - - - - - - - - - - -  name
	local remember, pointers = nil, 0;
	local len = self:byte();
	local n = {};
	while len > 0 do
		if len >= 0xc0 then    -- name is "compressed"
			pointers = pointers + 1;
			if pointers >= 20 then error('dns error: 20 pointers'); end;
			local offset = ((len-0xc0)*0x100) + self:byte();
			remember = remember or self.offset;
			self.offset = offset + 1;    -- +1 for lua
		else    -- name is not compressed
			append(n, self:sub(len)..'.');
		end
		len = self:byte();
	end
	self.offset = remember or self.offset;
	return table.concat(n);
end


function resolver:question()    -- - - - - - - - - - - - - - - - - -  question
	local q = {};
	q.name  = self:name();
	q.type  = dns.type[self:word()];
	q.class = dns.class[self:word()];
	return q;
end


function resolver:A(rr)    -- - - - - - - - - - - - - - - - - - - - - - - -  A
	local b1, b2, b3, b4 = self:byte(4);
	rr.a = string.format('%i.%i.%i.%i', b1, b2, b3, b4);
end

function resolver:AAAA(rr)
	local addr = {};
	for i = 1, rr.rdlength, 2 do
		local b1, b2 = self:byte(2);
		table.insert(addr, ("%02x%02x"):format(b1, b2));
	end
	addr = table.concat(addr, ":"):gsub("%f[%x]0+(%x)","%1");
	local zeros = {};
	for item in addr:gmatch(":[0:]+:") do
		table.insert(zeros, item)
	end
	if #zeros == 0 then
		rr.aaaa = addr;
		return
	elseif #zeros > 1 then
		table.sort(zeros, function(a, b) return #a > #b end);
	end
	rr.aaaa = addr:gsub(zeros[1], "::", 1):gsub("^0::", "::"):gsub("::0$", "::");
end

function resolver:CNAME(rr)    -- - - - - - - - - - - - - - - - - - - -  CNAME
	rr.cname = self:name();
end


function resolver:MX(rr)    -- - - - - - - - - - - - - - - - - - - - - - -  MX
	rr.pref = self:word();
	rr.mx   = self:name();
end


function resolver:LOC_nibble_power()    -- - - - - - - - - -  LOC_nibble_power
	local b = self:byte();
	--print('nibbles', ((b-(b%0x10))/0x10), (b%0x10));
	return ((b-(b%0x10))/0x10) * (10^(b%0x10));
end


function resolver:LOC(rr)    -- - - - - - - - - - - - - - - - - - - - - -  LOC
	rr.version = self:byte();
	if rr.version == 0 then
		rr.loc           = rr.loc or {};
		rr.loc.size      = self:LOC_nibble_power();
		rr.loc.horiz_pre = self:LOC_nibble_power();
		rr.loc.vert_pre  = self:LOC_nibble_power();
		rr.loc.latitude  = self:dword();
		rr.loc.longitude = self:dword();
		rr.loc.altitude  = self:dword();
	end
end


local function LOC_tostring_degrees(f, pos, neg)    -- - - - - - - - - - - - -
	f = f - 0x80000000;
	if f < 0 then pos = neg; f = -f; end
	local deg, min, msec;
	msec = f%60000;
	f    = (f-msec)/60000;
	min  = f%60;
	deg = (f-min)/60;
	return string.format('%3d %2d %2.3f %s', deg, min, msec/1000, pos);
end


function resolver.LOC_tostring(rr)    -- - - - - - - - - - - - -  LOC_tostring
	local t = {};

	--[[
	for k,name in pairs { 'size', 'horiz_pre', 'vert_pre', 'latitude', 'longitude', 'altitude' } do
		append(t, string.format('%4s%-10s: %12.0f\n', '', name, rr.loc[name]));
	end
	--]]

	append(t, string.format(
		'%s    %s    %.2fm %.2fm %.2fm %.2fm',
		LOC_tostring_degrees (rr.loc.latitude, 'N', 'S'),
		LOC_tostring_degrees (rr.loc.longitude, 'E', 'W'),
		(rr.loc.altitude - 10000000) / 100,
		rr.loc.size / 100,
		rr.loc.horiz_pre / 100,
		rr.loc.vert_pre / 100
	));

	return table.concat(t);
end


function resolver:NS(rr)    -- - - - - - - - - - - - - - - - - - - - - - -  NS
	rr.ns = self:name();
end


function resolver:SOA(rr)    -- - - - - - - - - - - - - - - - - - - - - -  SOA
end


function resolver:SRV(rr)    -- - - - - - - - - - - - - - - - - - - - - -  SRV
	  rr.srv = {};
	  rr.srv.priority = self:word();
	  rr.srv.weight   = self:word();
	  rr.srv.port     = self:word();
	  rr.srv.target   = self:name();
end

function resolver:PTR(rr)
	rr.ptr = self:name();
end

function resolver:TXT(rr)    -- - - - - - - - - - - - - - - - - - - - - -  TXT
	rr.txt = self:sub (self:byte());
end


function resolver:rr()    -- - - - - - - - - - - - - - - - - - - - - - - -  rr
	local rr = {};
	setmetatable(rr, rr_metatable);
	rr.name     = self:name(self);
	rr.type     = dns.type[self:word()] or rr.type;
	rr.class    = dns.class[self:word()] or rr.class;
	rr.ttl      = 0x10000*self:word() + self:word();
	rr.rdlength = self:word();

	if rr.ttl <= 0 then
		rr.tod = self.time + 30;
	else
		rr.tod = self.time + rr.ttl;
	end

	local remember = self.offset;
	local rr_parser = self[dns.type[rr.type]];
	if rr_parser then rr_parser(self, rr); end
	self.offset = remember;
	rr.rdata = self:sub(rr.rdlength);
	return rr;
end


function resolver:rrs (count)    -- - - - - - - - - - - - - - - - - - - - - rrs
	local rrs = {};
	for i = 1,count do append(rrs, self:rr()); end
	return rrs;
end


function resolver:decode(packet, force)    -- - - - - - - - - - - - - - decode
	self.packet, self.offset = packet, 1;
	local header = self:header(force);
	if not header then return nil; end
	local response = { header = header };

	response.question = {};
	local offset = self.offset;
	for i = 1,response.header.qdcount do
		append(response.question, self:question());
	end
	response.question.raw = string.sub(self.packet, offset, self.offset - 1);

	if not force then
		if not self.active[response.header.id] or not self.active[response.header.id][response.question.raw] then
			return nil;
		end
	end

	response.answer     = self:rrs(response.header.ancount);
	response.authority  = self:rrs(response.header.nscount);
	response.additional = self:rrs(response.header.arcount);

	return response;
end


-- socket layer -------------------------------------------------- socket layer


resolver.delays = { 1, 3 };


function resolver:addnameserver(address)    -- - - - - - - - - - addnameserver
	self.server = self.server or {};
	append(self.server, address);
end


function resolver:setnameserver(address)    -- - - - - - - - - - setnameserver
	self.server = {};
	self:addnameserver(address);
end


function resolver:adddefaultnameservers()    -- - - - -  adddefaultnameservers
	if is_windows then
		if windows and windows.get_nameservers then
			for _, server in ipairs(windows.get_nameservers()) do
				self:addnameserver(server);
			end
		end
		if not self.server or #self.server == 0 then
			-- TODO log warning about no nameservers, adding opendns servers as fallback
			self:addnameserver("208.67.222.222");
			self:addnameserver("208.67.220.220");
		end
	else -- posix
		local resolv_conf = io.open("/etc/resolv.conf");
		if resolv_conf then
			for line in resolv_conf:lines() do
				line = line:gsub("#.*$", "")
					:match('^%s*nameserver%s+(.*)%s*$');
				if line then
					line:gsub("%f[%d.](%d+%.%d+%.%d+%.%d+)%f[^%d.]", function (address)
						self:addnameserver(address)
					end);
				end
			end
		end
		if not self.server or #self.server == 0 then
			-- TODO log warning about no nameservers, adding localhost as the default nameserver
			self:addnameserver("127.0.0.1");
		end
	end
end


function resolver:getsocket(servernum)    -- - - - - - - - - - - - - getsocket
	self.socket = self.socket or {};
	self.socketset = self.socketset or {};

	local sock = self.socket[servernum];
	if sock then return sock; end

	local err;
	sock, err = socket.udp();
	if not sock then
		return nil, err;
	end
	if self.socket_wrapper then sock = self.socket_wrapper(sock, self); end
	sock:settimeout(0);
	-- todo: attempt to use a random port, fallback to 0
	sock:setsockname('*', 0);
	sock:setpeername(self.server[servernum], 53);
	self.socket[servernum] = sock;
	self.socketset[sock] = servernum;
	return sock;
end

function resolver:voidsocket(sock)
	if self.socket[sock] then
		self.socketset[self.socket[sock]] = nil;
		self.socket[sock] = nil;
	elseif self.socketset[sock] then
		self.socket[self.socketset[sock]] = nil;
		self.socketset[sock] = nil;
	end
end

function resolver:socket_wrapper_set(func)  -- - - - - - - socket_wrapper_set
	self.socket_wrapper = func;
end


function resolver:closeall ()    -- - - - - - - - - - - - - - - - - -  closeall
	for i,sock in ipairs(self.socket) do
		self.socket[i] = nil;
		self.socketset[sock] = nil;
		sock:close();
	end
end


function resolver:remember(rr, type)    -- - - - - - - - - - - - - -  remember
	--print ('remember', type, rr.class, rr.type, rr.name)
	local qname, qtype, qclass = standardize(rr.name, rr.type, rr.class);

	if type ~= '*' then
		type = qtype;
		local all = get(self.cache, qclass, '*', qname);
		--print('remember all', all);
		if all then append(all, rr); end
	end

	self.cache = self.cache or setmetatable({}, cache_metatable);
	local rrs = get(self.cache, qclass, type, qname) or
		set(self.cache, qclass, type, qname, setmetatable({}, rrs_metatable));
	append(rrs, rr);

	if type == 'MX' then self.unsorted[rrs] = true; end
end


local function comp_mx(a, b)    -- - - - - - - - - - - - - - - - - - - comp_mx
	return (a.pref == b.pref) and (a.mx < b.mx) or (a.pref < b.pref);
end


function resolver:peek (qname, qtype, qclass)    -- - - - - - - - - - - -  peek
	qname, qtype, qclass = standardize(qname, qtype, qclass);
	local rrs = get(self.cache, qclass, qtype, qname);
	if not rrs then return nil; end
	if prune(rrs, socket.gettime()) and qtype == '*' or not next(rrs) then
		set(self.cache, qclass, qtype, qname, nil);
		return nil;
	end
	if self.unsorted[rrs] then table.sort (rrs, comp_mx); end
	return rrs;
end


function resolver:purge(soft)    -- - - - - - - - - - - - - - - - - - -  purge
	if soft == 'soft' then
		self.time = socket.gettime();
		for class,types in pairs(self.cache or {}) do
			for type,names in pairs(types) do
				for name,rrs in pairs(names) do
					prune(rrs, self.time, 'soft')
				end
			end
		end
	else self.cache = {}; end
end


function resolver:query(qname, qtype, qclass)    -- - - - - - - - - - -- query
	qname, qtype, qclass = standardize(qname, qtype, qclass)

	if not self.server then self:adddefaultnameservers(); end

	local question = encodeQuestion(qname, qtype, qclass);
	local peek = self:peek (qname, qtype, qclass);
	if peek then return peek; end

	local header, id = encodeHeader();
	--print ('query  id', id, qclass, qtype, qname)
	local o = {
		packet = header..question,
		server = self.best_server,
		delay  = 1,
		retry  = socket.gettime() + self.delays[1]
	};

	-- remember the query
	self.active[id] = self.active[id] or {};
	self.active[id][question] = o;

	-- remember which coroutine wants the answer
	local co = coroutine.running();
	if co then
		set(self.wanted, qclass, qtype, qname, co, true);
		--set(self.yielded, co, qclass, qtype, qname, true);
	end

	local conn, err = self:getsocket(o.server)
	if not conn then
		return nil, err;
	end
	conn:send (o.packet)
	
	if timer and self.timeout then
		local num_servers = #self.server;
		local i = 1;
		timer.add_task(self.timeout, function ()
			if get(self.wanted, qclass, qtype, qname, co) then
				if i < num_servers then
					i = i + 1;
					self:servfail(conn);
					o.server = self.best_server;
					conn, err = self:getsocket(o.server);
					if conn then
						conn:send(o.packet);
						return self.timeout;
					end
				end
				-- Tried everything, failed
				self:cancel(qclass, qtype, qname, co, true);
			end
		end)
	end
	return true;
end

function resolver:servfail(sock)
	-- Resend all queries for this server

	local num = self.socketset[sock]

	-- Socket is dead now
	self:voidsocket(sock);

	-- Find all requests to the down server, and retry on the next server
	self.time = socket.gettime();
	for id,queries in pairs(self.active) do
		for question,o in pairs(queries) do
			if o.server == num then -- This request was to the broken server
				o.server = o.server + 1 -- Use next server
				if o.server > #self.server then
					o.server = 1;
				end

				o.retries = (o.retries or 0) + 1;
				if o.retries >= #self.server then
					--print('timeout');
					queries[question] = nil;
				else
					local _a = self:getsocket(o.server);
					if _a then _a:send(o.packet); end
				end
			end
		end
	end

	if num == self.best_server then
		self.best_server = self.best_server + 1;
		if self.best_server > #self.server then
			-- Exhausted all servers, try first again
			self.best_server = 1;
		end
	end
end

function resolver:settimeout(seconds)
	self.timeout = seconds;
end

function resolver:receive(rset)    -- - - - - - - - - - - - - - - - -  receive
	--print('receive');  print(self.socket);
	self.time = socket.gettime();
	rset = rset or self.socket;

	local response;
	for i,sock in pairs(rset) do

		if self.socketset[sock] then
			local packet = sock:receive();
			if packet then
				response = self:decode(packet);
				if response and self.active[response.header.id]
					and self.active[response.header.id][response.question.raw] then
					--print('received response');
					--self.print(response);

					for j,rr in pairs(response.answer) do
						if rr.name:sub(-#response.question[1].name, -1) == response.question[1].name then
							self:remember(rr, response.question[1].type)
						end
					end

					-- retire the query
					local queries = self.active[response.header.id];
					queries[response.question.raw] = nil;
					
					if not next(queries) then self.active[response.header.id] = nil; end
					if not next(self.active) then self:closeall(); end

					-- was the query on the wanted list?
					local q = response.question[1];
					local cos = get(self.wanted, q.class, q.type, q.name);
					if cos then
						for co in pairs(cos) do
							set(self.yielded, co, q.class, q.type, q.name, nil);
							if coroutine.status(co) == "suspended" then coroutine.resume(co); end
						end
						set(self.wanted, q.class, q.type, q.name, nil);
					end
				end
			end
		end
	end

	return response;
end


function resolver:feed(sock, packet, force)
	--print('receive'); print(self.socket);
	self.time = socket.gettime();

	local response = self:decode(packet, force);
	if response and self.active[response.header.id]
		and self.active[response.header.id][response.question.raw] then
		--print('received response');
		--self.print(response);

		for j,rr in pairs(response.answer) do
			self:remember(rr, response.question[1].type);
		end

		-- retire the query
		local queries = self.active[response.header.id];
		queries[response.question.raw] = nil;
		if not next(queries) then self.active[response.header.id] = nil; end
		if not next(self.active) then self:closeall(); end

		-- was the query on the wanted list?
		local q = response.question[1];
		if q then
			local cos = get(self.wanted, q.class, q.type, q.name);
			if cos then
				for co in pairs(cos) do
					set(self.yielded, co, q.class, q.type, q.name, nil);
					if coroutine.status(co) == "suspended" then coroutine.resume(co); end
				end
				set(self.wanted, q.class, q.type, q.name, nil);
			end
		end
	end

	return response;
end

function resolver:cancel(qclass, qtype, qname, co, call_handler)
	local cos = get(self.wanted, qclass, qtype, qname);
	if cos then
		if call_handler then
			coroutine.resume(co);
		end
		cos[co] = nil;
	end
end

function resolver:pulse()    -- - - - - - - - - - - - - - - - - - - - -  pulse
	--print(':pulse');
	while self:receive() do end
	if not next(self.active) then return nil; end

	self.time = socket.gettime();
	for id,queries in pairs(self.active) do
		for question,o in pairs(queries) do
			if self.time >= o.retry then

				o.server = o.server + 1;
				if o.server > #self.server then
					o.server = 1;
					o.delay = o.delay + 1;
				end

				if o.delay > #self.delays then
					--print('timeout');
					queries[question] = nil;
					if not next(queries) then self.active[id] = nil; end
					if not next(self.active) then return nil; end
				else
					--print('retry', o.server, o.delay);
					local _a = self.socket[o.server];
					if _a then _a:send(o.packet); end
					o.retry = self.time + self.delays[o.delay];
				end
			end
		end
	end

	if next(self.active) then return true; end
	return nil;
end


function resolver:lookup(qname, qtype, qclass)    -- - - - - - - - - -  lookup
	self:query (qname, qtype, qclass)
	while self:pulse() do
		local recvt = {}
		for i, s in ipairs(self.socket) do
			recvt[i] = s
		end
		socket.select(recvt, nil, 4)
	end
	--print(self.cache);
	return self:peek(qname, qtype, qclass);
end

function resolver:lookupex(handler, qname, qtype, qclass)    -- - - - - - - - - -  lookup
	return self:peek(qname, qtype, qclass) or self:query(qname, qtype, qclass);
end

function resolver:tohostname(ip)
	return dns.lookup(ip:gsub("(%d+)%.(%d+)%.(%d+)%.(%d+)", "%4.%3.%2.%1.in-addr.arpa."), "PTR");
end

--print ---------------------------------------------------------------- print


local hints = {    -- - - - - - - - - - - - - - - - - - - - - - - - - - - hints
	qr = { [0]='query', 'response' },
	opcode = { [0]='query', 'inverse query', 'server status request' },
	aa = { [0]='non-authoritative', 'authoritative' },
	tc = { [0]='complete', 'truncated' },
	rd = { [0]='recursion not desired', 'recursion desired' },
	ra = { [0]='recursion not available', 'recursion available' },
	z  = { [0]='(reserved)' },
	rcode = { [0]='no error', 'format error', 'server failure', 'name error', 'not implemented' },

	type = dns.type,
	class = dns.class
};


local function hint(p, s)    -- - - - - - - - - - - - - - - - - - - - - - hint
	return (hints[s] and hints[s][p[s]]) or '';
end


function resolver.print(response)    -- - - - - - - - - - - - - resolver.print
	for s,s in pairs { 'id', 'qr', 'opcode', 'aa', 'tc', 'rd', 'ra', 'z',
						'rcode', 'qdcount', 'ancount', 'nscount', 'arcount' } do
		print( string.format('%-30s', 'header.'..s), response.header[s], hint(response.header, s) );
	end

	for i,question in ipairs(response.question) do
		print(string.format ('question[%i].name         ', i), question.name);
		print(string.format ('question[%i].type         ', i), question.type);
		print(string.format ('question[%i].class        ', i), question.class);
	end

	local common = { name=1, type=1, class=1, ttl=1, rdlength=1, rdata=1 };
	local tmp;
	for s,s in pairs({'answer', 'authority', 'additional'}) do
		for i,rr in pairs(response[s]) do
			for j,t in pairs({ 'name', 'type', 'class', 'ttl', 'rdlength' }) do
				tmp = string.format('%s[%i].%s', s, i, t);
				print(string.format('%-30s', tmp), rr[t], hint(rr, t));
			end
			for j,t in pairs(rr) do
				if not common[j] then
					tmp = string.format('%s[%i].%s', s, i, j);
					print(string.format('%-30s  %s', tostring(tmp), tostring(t)));
				end
			end
		end
	end
end


-- module api ------------------------------------------------------ module api


function dns.resolver ()    -- - - - - - - - - - - - - - - - - - - - - resolver
	-- this function seems to be redundant with resolver.new ()

	local r = { active = {}, cache = {}, unsorted = {}, wanted = {}, yielded = {}, best_server = 1 };
	setmetatable (r, resolver);
	setmetatable (r.cache, cache_metatable);
	setmetatable (r.unsorted, { __mode = 'kv' });
	return r;
end

local _resolver = dns.resolver();
dns._resolver = _resolver;

function dns.lookup(...)    -- - - - - - - - - - - - - - - - - - - - -  lookup
	return _resolver:lookup(...);
end

function dns.tohostname(...)
	return _resolver:tohostname(...);
end

function dns.purge(...)    -- - - - - - - - - - - - - - - - - - - - - -  purge
	return _resolver:purge(...);
end

function dns.peek(...)    -- - - - - - - - - - - - - - - - - - - - - - -  peek
	return _resolver:peek(...);
end

function dns.query(...)    -- - - - - - - - - - - - - - - - - - - - - -  query
	return _resolver:query(...);
end

function dns.feed(...)    -- - - - - - - - - - - - - - - - - - - - - - -  feed
	return _resolver:feed(...);
end

function dns.cancel(...)  -- - - - - - - - - - - - - - - - - - - - - -  cancel
	return _resolver:cancel(...);
end

function dns.settimeout(...)
	return _resolver:settimeout(...);
end

function dns.socket_wrapper_set(...)    -- - - - - - - - -  socket_wrapper_set
	return _resolver:socket_wrapper_set(...);
end

return dns;
 end)
package.preload['net.adns'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local server = require "net.server";
local dns = require "net.dns";

local log = require "util.logger".init("adns");

local t_insert, t_remove = table.insert, table.remove;
local coroutine, tostring, pcall = coroutine, tostring, pcall;

local function dummy_send(sock, data, i, j) return (j-i)+1; end

module "adns"

function lookup(handler, qname, qtype, qclass)
	return coroutine.wrap(function (peek)
				if peek then
					log("debug", "Records for %s already cached, using those...", qname);
					handler(peek);
					return;
				end
				log("debug", "Records for %s not in cache, sending query (%s)...", qname, tostring(coroutine.running()));
				local ok, err = dns.query(qname, qtype, qclass);
				if ok then
					coroutine.yield({ qclass or "IN", qtype or "A", qname, coroutine.running()}); -- Wait for reply
					log("debug", "Reply for %s (%s)", qname, tostring(coroutine.running()));
				end
				if ok then
					ok, err = pcall(handler, dns.peek(qname, qtype, qclass));
				else
					log("error", "Error sending DNS query: %s", err);
					ok, err = pcall(handler, nil, err);
				end
				if not ok then
					log("error", "Error in DNS response handler: %s", tostring(err));
				end
			end)(dns.peek(qname, qtype, qclass));
end

function cancel(handle, call_handler, reason)
	log("warn", "Cancelling DNS lookup for %s", tostring(handle[3]));
	dns.cancel(handle[1], handle[2], handle[3], handle[4], call_handler);
end

function new_async_socket(sock, resolver)
	local peername = "<unknown>";
	local listener = {};
	local handler = {};
	function listener.onincoming(conn, data)
		if data then
			dns.feed(handler, data);
		end
	end
	function listener.ondisconnect(conn, err)
		if err then
			log("warn", "DNS socket for %s disconnected: %s", peername, err);
			local servers = resolver.server;
			if resolver.socketset[conn] == resolver.best_server and resolver.best_server == #servers then
				log("error", "Exhausted all %d configured DNS servers, next lookup will try %s again", #servers, servers[1]);
			end
		
			resolver:servfail(conn); -- Let the magic commence
		end
	end
	handler = server.wrapclient(sock, "dns", 53, listener);
	if not handler then
		log("warn", "handler is nil");
	end
	
	handler.settimeout = function () end
	handler.setsockname = function (_, ...) return sock:setsockname(...); end
	handler.setpeername = function (_, ...) peername = (...); local ret = sock:setpeername(...); _:set_send(dummy_send); return ret; end
	handler.connect = function (_, ...) return sock:connect(...) end
	--handler.send = function (_, data) _:write(data);  return _.sendbuffer and _.sendbuffer(); end
	handler.send = function (_, data)
		local getpeername = sock.getpeername;
		log("debug", "Sending DNS query to %s", (getpeername and getpeername(sock)) or "<unconnected>");
		return sock:send(data);
	end
	return handler;
end

dns.socket_wrapper_set(new_async_socket);

return _M;
 end)
package.preload['net.server'] = (function (...)
-- 
-- server.lua by blastbeat of the luadch project
-- Re-used here under the MIT/X Consortium License
-- 
-- Modifications (C) 2008-2010 Matthew Wild, Waqas Hussain
--

-- // wrapping luadch stuff // --

local use = function( what )
	return _G[ what ]
end
local clean = function( tbl )
	for i, k in pairs( tbl ) do
		tbl[ i ] = nil
	end
end

local log, table_concat = require ("util.logger").init("socket"), table.concat;
local out_put = function (...) return log("debug", table_concat{...}); end
local out_error = function (...) return log("warn", table_concat{...}); end
local mem_free = collectgarbage

----------------------------------// DECLARATION //--

--// constants //--

local STAT_UNIT = 1 -- byte

--// lua functions //--

local type = use "type"
local pairs = use "pairs"
local ipairs = use "ipairs"
local tonumber = use "tonumber"
local tostring = use "tostring"
local collectgarbage = use "collectgarbage"

--// lua libs //--

local os = use "os"
local table = use "table"
local string = use "string"
local coroutine = use "coroutine"

--// lua lib methods //--

local os_difftime = os.difftime
local math_min = math.min
local math_huge = math.huge
local table_concat = table.concat
local table_remove = table.remove
local string_len = string.len
local string_sub = string.sub
local coroutine_wrap = coroutine.wrap
local coroutine_yield = coroutine.yield

--// extern libs //--

local luasec = use "ssl"
local luasocket = use "socket" or require "socket"
local luasocket_gettime = luasocket.gettime

--// extern lib methods //--

local ssl_wrap = ( luasec and luasec.wrap )
local socket_bind = luasocket.bind
local socket_sleep = luasocket.sleep
local socket_select = luasocket.select
local ssl_newcontext = ( luasec and luasec.newcontext )

--// functions //--

local id
local loop
local stats
local idfalse
local addtimer
local closeall
local addsocket
local addserver
local getserver
local wrapserver
local getsettings
local closesocket
local removesocket
local removeserver
local changetimeout
local wrapconnection
local changesettings

--// tables //--

local _server
local _readlist
local _timerlist
local _sendlist
local _socketlist
local _closelist
local _readtimes
local _writetimes

--// simple data types //--

local _
local _readlistlen
local _sendlistlen
local _timerlistlen

local _sendtraffic
local _readtraffic

local _selecttimeout
local _sleeptime

local _starttime
local _currenttime

local _maxsendlen
local _maxreadlen

local _checkinterval
local _sendtimeout
local _readtimeout

local _cleanqueue

local _timer

local _maxclientsperserver

local _maxsslhandshake

----------------------------------// DEFINITION //--

_server = { } -- key = port, value = table; list of listening servers
_readlist = { } -- array with sockets to read from
_sendlist = { } -- arrary with sockets to write to
_timerlist = { } -- array of timer functions
_socketlist = { } -- key = socket, value = wrapped socket (handlers)
_readtimes = { } -- key = handler, value = timestamp of last data reading
_writetimes = { } -- key = handler, value = timestamp of last data writing/sending
_closelist = { } -- handlers to close

_readlistlen = 0 -- length of readlist
_sendlistlen = 0 -- length of sendlist
_timerlistlen = 0 -- lenght of timerlist

_sendtraffic = 0 -- some stats
_readtraffic = 0

_selecttimeout = 1 -- timeout of socket.select
_sleeptime = 0 -- time to wait at the end of every loop

_maxsendlen = 51000 * 1024 -- max len of send buffer
_maxreadlen = 25000 * 1024 -- max len of read buffer

_checkinterval = 1200000 -- interval in secs to check idle clients
_sendtimeout = 60000 -- allowed send idle time in secs
_readtimeout = 6 * 60 * 60 -- allowed read idle time in secs

_cleanqueue = false -- clean bufferqueue after using

_maxclientsperserver = 1000

_maxsslhandshake = 30 -- max handshake round-trips

----------------------------------// PRIVATE //--

wrapserver = function( listeners, socket, ip, serverport, pattern, sslctx, maxconnections ) -- this function wraps a server

	maxconnections = maxconnections or _maxclientsperserver

	local connections = 0

	local dispatch, disconnect = listeners.onconnect or listeners.onincoming, listeners.ondisconnect

	local accept = socket.accept

	--// public methods of the object //--

	local handler = { }

	handler.shutdown = function( ) end

	handler.ssl = function( )
		return sslctx ~= nil
	end
	handler.sslctx = function( )
		return sslctx
	end
	handler.remove = function( )
		connections = connections - 1
	end
	handler.close = function( )
		for _, handler in pairs( _socketlist ) do
			if handler.serverport == serverport then
				handler.disconnect( handler, "server closed" )
				handler:close( true )
			end
		end
		socket:close( )
		_sendlistlen = removesocket( _sendlist, socket, _sendlistlen )
		_readlistlen = removesocket( _readlist, socket, _readlistlen )
		_socketlist[ socket ] = nil
		handler = nil
		socket = nil
		--mem_free( )
		out_put "server.lua: closed server handler and removed sockets from list"
	end
	handler.ip = function( )
		return ip
	end
	handler.serverport = function( )
		return serverport
	end
	handler.socket = function( )
		return socket
	end
	handler.readbuffer = function( )
		if connections > maxconnections then
			out_put( "server.lua: refused new client connection: server full" )
			return false
		end
		local client, err = accept( socket )	-- try to accept
		if client then
			local ip, clientport = client:getpeername( )
			client:settimeout( 0 )
			local handler, client, err = wrapconnection( handler, listeners, client, ip, serverport, clientport, pattern, sslctx ) -- wrap new client socket
			if err then -- error while wrapping ssl socket
				return false
			end
			connections = connections + 1
			out_put( "server.lua: accepted new client connection from ", tostring(ip), ":", tostring(clientport), " to ", tostring(serverport))
			return dispatch( handler )
		elseif err then -- maybe timeout or something else
			out_put( "server.lua: error with new client connection: ", tostring(err) )
			return false
		end
	end
	return handler
end

wrapconnection = function( server, listeners, socket, ip, serverport, clientport, pattern, sslctx ) -- this function wraps a client to a handler object

	socket:settimeout( 0 )

	--// local import of socket methods //--

	local send
	local receive
	local shutdown

	--// private closures of the object //--

	local ssl

	local dispatch = listeners.onincoming
	local status = listeners.onstatus
	local disconnect = listeners.ondisconnect
	local drain = listeners.ondrain

	local bufferqueue = { } -- buffer array
	local bufferqueuelen = 0	-- end of buffer array

	local toclose
	local fatalerror
	local needtls

	local bufferlen = 0

	local noread = false
	local nosend = false

	local sendtraffic, readtraffic = 0, 0

	local maxsendlen = _maxsendlen
	local maxreadlen = _maxreadlen

	--// public methods of the object //--

	local handler = bufferqueue -- saves a table ^_^

	handler.dispatch = function( )
		return dispatch
	end
	handler.disconnect = function( )
		return disconnect
	end
	handler.setlistener = function( self, listeners )
		dispatch = listeners.onincoming
		disconnect = listeners.ondisconnect
		status = listeners.onstatus
		drain = listeners.ondrain
	end
	handler.getstats = function( )
		return readtraffic, sendtraffic
	end
	handler.ssl = function( )
		return ssl
	end
	handler.sslctx = function ( )
		return sslctx
	end
	handler.send = function( _, data, i, j )
		return send( socket, data, i, j )
	end
	handler.receive = function( pattern, prefix )
		return receive( socket, pattern, prefix )
	end
	handler.shutdown = function( pattern )
		return shutdown( socket, pattern )
	end
	handler.setoption = function (self, option, value)
		if socket.setoption then
			return socket:setoption(option, value);
		end
		return false, "setoption not implemented";
	end
	handler.close = function( self, forced )
		if not handler then return true; end
		_readlistlen = removesocket( _readlist, socket, _readlistlen )
		_readtimes[ handler ] = nil
		if bufferqueuelen ~= 0 then
			if not ( forced or fatalerror ) then
				handler.sendbuffer( )
				if bufferqueuelen ~= 0 then -- try again...
					if handler then
						handler.write = nil -- ... but no further writing allowed
					end
					toclose = true
					return false
				end
			else
				send( socket, table_concat( bufferqueue, "", 1, bufferqueuelen ), 1, bufferlen )	-- forced send
			end
		end
		if socket then
			_ = shutdown and shutdown( socket )
			socket:close( )
			_sendlistlen = removesocket( _sendlist, socket, _sendlistlen )
			_socketlist[ socket ] = nil
			socket = nil
		else
			out_put "server.lua: socket already closed"
		end
		if handler then
			_writetimes[ handler ] = nil
			_closelist[ handler ] = nil
			handler = nil
		end
		if server then
			server.remove( )
		end
		out_put "server.lua: closed client handler and removed socket from list"
		return true
	end
	handler.ip = function( )
		return ip
	end
	handler.serverport = function( )
		return serverport
	end
	handler.clientport = function( )
		return clientport
	end
	local write = function( self, data )
		bufferlen = bufferlen + string_len( data )
		if bufferlen > maxsendlen then
			_closelist[ handler ] = "send buffer exceeded"	 -- cannot close the client at the moment, have to wait to the end of the cycle
			handler.write = idfalse -- dont write anymore
			return false
		elseif socket and not _sendlist[ socket ] then
			_sendlistlen = addsocket(_sendlist, socket, _sendlistlen)
		end
		bufferqueuelen = bufferqueuelen + 1
		bufferqueue[ bufferqueuelen ] = data
		if handler then
			_writetimes[ handler ] = _writetimes[ handler ] or _currenttime
		end
		return true
	end
	handler.write = write
	handler.bufferqueue = function( self )
		return bufferqueue
	end
	handler.socket = function( self )
		return socket
	end
	handler.set_mode = function( self, new )
		pattern = new or pattern
		return pattern
	end
	handler.set_send = function ( self, newsend )
		send = newsend or send
		return send
	end
	handler.bufferlen = function( self, readlen, sendlen )
		maxsendlen = sendlen or maxsendlen
		maxreadlen = readlen or maxreadlen
		return bufferlen, maxreadlen, maxsendlen
	end
	--TODO: Deprecate
	handler.lock_read = function (self, switch)
		if switch == true then
			local tmp = _readlistlen
			_readlistlen = removesocket( _readlist, socket, _readlistlen )
			_readtimes[ handler ] = nil
			if _readlistlen ~= tmp then
				noread = true
			end
		elseif switch == false then
			if noread then
				noread = false
				_readlistlen = addsocket(_readlist, socket, _readlistlen)
				_readtimes[ handler ] = _currenttime
			end
		end
		return noread
	end
	handler.pause = function (self)
		return self:lock_read(true);
	end
	handler.resume = function (self)
		return self:lock_read(false);
	end
	handler.lock = function( self, switch )
		handler.lock_read (switch)
		if switch == true then
			handler.write = idfalse
			local tmp = _sendlistlen
			_sendlistlen = removesocket( _sendlist, socket, _sendlistlen )
			_writetimes[ handler ] = nil
			if _sendlistlen ~= tmp then
				nosend = true
			end
		elseif switch == false then
			handler.write = write
			if nosend then
				nosend = false
				write( "" )
			end
		end
		return noread, nosend
	end
	local _readbuffer = function( ) -- this function reads data
		local buffer, err, part = receive( socket, pattern )	-- receive buffer with "pattern"
		if not err or (err == "wantread" or err == "timeout") then -- received something
			local buffer = buffer or part or ""
			local len = string_len( buffer )
			if len > maxreadlen then
				disconnect( handler, "receive buffer exceeded" )
				handler:close( true )
				return false
			end
			local count = len * STAT_UNIT
			readtraffic = readtraffic + count
			_readtraffic = _readtraffic + count
			_readtimes[ handler ] = _currenttime
			--out_put( "server.lua: read data '", buffer:gsub("[^%w%p ]", "."), "', error: ", err )
			return dispatch( handler, buffer, err )
		else	-- connections was closed or fatal error
			out_put( "server.lua: client ", tostring(ip), ":", tostring(clientport), " read error: ", tostring(err) )
			fatalerror = true
			disconnect( handler, err )
		_ = handler and handler:close( )
			return false
		end
	end
	local _sendbuffer = function( ) -- this function sends data
		local succ, err, byte, buffer, count;
		local count;
		if socket then
			buffer = table_concat( bufferqueue, "", 1, bufferqueuelen )
			succ, err, byte = send( socket, buffer, 1, bufferlen )
			count = ( succ or byte or 0 ) * STAT_UNIT
			sendtraffic = sendtraffic + count
			_sendtraffic = _sendtraffic + count
			_ = _cleanqueue and clean( bufferqueue )
			--out_put( "server.lua: sended '", buffer, "', bytes: ", tostring(succ), ", error: ", tostring(err), ", part: ", tostring(byte), ", to: ", tostring(ip), ":", tostring(clientport) )
		else
			succ, err, count = false, "closed", 0;
		end
		if succ then	-- sending succesful
			bufferqueuelen = 0
			bufferlen = 0
			_sendlistlen = removesocket( _sendlist, socket, _sendlistlen ) -- delete socket from writelist
			_writetimes[ handler ] = nil
			if drain then
				drain(handler)
			end
			_ = needtls and handler:starttls(nil)
			_ = toclose and handler:close( )
			return true
		elseif byte and ( err == "timeout" or err == "wantwrite" ) then -- want write
			buffer = string_sub( buffer, byte + 1, bufferlen ) -- new buffer
			bufferqueue[ 1 ] = buffer	 -- insert new buffer in queue
			bufferqueuelen = 1
			bufferlen = bufferlen - byte
			_writetimes[ handler ] = _currenttime
			return true
		else	-- connection was closed during sending or fatal error
			out_put( "server.lua: client ", tostring(ip), ":", tostring(clientport), " write error: ", tostring(err) )
			fatalerror = true
			disconnect( handler, err )
			_ = handler and handler:close( )
			return false
		end
	end

	-- Set the sslctx
	local handshake;
	function handler.set_sslctx(self, new_sslctx)
		sslctx = new_sslctx;
		local read, wrote
		handshake = coroutine_wrap( function( client ) -- create handshake coroutine
				local err
				for i = 1, _maxsslhandshake do
					_sendlistlen = ( wrote and removesocket( _sendlist, client, _sendlistlen ) ) or _sendlistlen
					_readlistlen = ( read and removesocket( _readlist, client, _readlistlen ) ) or _readlistlen
					read, wrote = nil, nil
					_, err = client:dohandshake( )
					if not err then
						out_put( "server.lua: ssl handshake done" )
						handler.readbuffer = _readbuffer	-- when handshake is done, replace the handshake function with regular functions
						handler.sendbuffer = _sendbuffer
						_ = status and status( handler, "ssl-handshake-complete" )
						if self.autostart_ssl and listeners.onconnect then
							listeners.onconnect(self);
						end
						_readlistlen = addsocket(_readlist, client, _readlistlen)
						return true
					else
						if err == "wantwrite" then
							_sendlistlen = addsocket(_sendlist, client, _sendlistlen)
							wrote = true
						elseif err == "wantread" then
							_readlistlen = addsocket(_readlist, client, _readlistlen)
							read = true
						else
							break;
						end
						err = nil;
						coroutine_yield( ) -- handshake not finished
					end
				end
				out_put( "server.lua: ssl handshake error: ", tostring(err or "handshake too long") )
				disconnect( handler, "ssl handshake failed" )
				_ = handler and handler:close( true )	 -- forced disconnect
				return false	-- handshake failed
			end
		)
	end
	if luasec then
		handler.starttls = function( self, _sslctx)
			if _sslctx then
				handler:set_sslctx(_sslctx);
			end
			if bufferqueuelen > 0 then
				out_put "server.lua: we need to do tls, but delaying until send buffer empty"
				needtls = true
				return
			end
			out_put( "server.lua: attempting to start tls on " .. tostring( socket ) )
			local oldsocket, err = socket
			socket, err = ssl_wrap( socket, sslctx )	-- wrap socket
			if not socket then
				out_put( "server.lua: error while starting tls on client: ", tostring(err or "unknown error") )
				return nil, err -- fatal error
			end

			socket:settimeout( 0 )

			-- add the new socket to our system
			send = socket.send
			receive = socket.receive
			shutdown = id
			_socketlist[ socket ] = handler
			_readlistlen = addsocket(_readlist, socket, _readlistlen)
			
			-- remove traces of the old socket
			_readlistlen = removesocket( _readlist, oldsocket, _readlistlen )
			_sendlistlen = removesocket( _sendlist, oldsocket, _sendlistlen )
			_socketlist[ oldsocket ] = nil

			handler.starttls = nil
			needtls = nil

			-- Secure now (if handshake fails connection will close)
			ssl = true

			handler.readbuffer = handshake
			handler.sendbuffer = handshake
			handshake( socket ) -- do handshake
		end
		handler.readbuffer = _readbuffer
		handler.sendbuffer = _sendbuffer
		
		if sslctx then
			out_put "server.lua: auto-starting ssl negotiation..."
			handler.autostart_ssl = true;
			handler:starttls(sslctx);
		end

	else
		handler.readbuffer = _readbuffer
		handler.sendbuffer = _sendbuffer
	end
	send = socket.send
	receive = socket.receive
	shutdown = ( ssl and id ) or socket.shutdown

	_socketlist[ socket ] = handler
	_readlistlen = addsocket(_readlist, socket, _readlistlen)
	return handler, socket
end

id = function( )
end

idfalse = function( )
	return false
end

addsocket = function( list, socket, len )
	if not list[ socket ] then
		len = len + 1
		list[ len ] = socket
		list[ socket ] = len
	end
	return len;
end

removesocket = function( list, socket, len )	-- this function removes sockets from a list ( copied from copas )
	local pos = list[ socket ]
	if pos then
		list[ socket ] = nil
		local last = list[ len ]
		list[ len ] = nil
		if last ~= socket then
			list[ last ] = pos
			list[ pos ] = last
		end
		return len - 1
	end
	return len
end

closesocket = function( socket )
	_sendlistlen = removesocket( _sendlist, socket, _sendlistlen )
	_readlistlen = removesocket( _readlist, socket, _readlistlen )
	_socketlist[ socket ] = nil
	socket:close( )
	--mem_free( )
end

local function link(sender, receiver, buffersize)
	local sender_locked;
	local _sendbuffer = receiver.sendbuffer;
	function receiver.sendbuffer()
		_sendbuffer();
		if sender_locked and receiver.bufferlen() < buffersize then
			sender:lock_read(false); -- Unlock now
			sender_locked = nil;
		end
	end
	
	local _readbuffer = sender.readbuffer;
	function sender.readbuffer()
		_readbuffer();
		if not sender_locked and receiver.bufferlen() >= buffersize then
			sender_locked = true;
			sender:lock_read(true);
		end
	end
end

----------------------------------// PUBLIC //--

addserver = function( addr, port, listeners, pattern, sslctx ) -- this function provides a way for other scripts to reg a server
	local err
	if type( listeners ) ~= "table" then
		err = "invalid listener table"
	end
	if type( port ) ~= "number" or not ( port >= 0 and port <= 65535 ) then
		err = "invalid port"
	elseif _server[ addr..":"..port ] then
		err = "listeners on '[" .. addr .. "]:" .. port .. "' already exist"
	elseif sslctx and not luasec then
		err = "luasec not found"
	end
	if err then
		out_error( "server.lua, [", addr, "]:", port, ": ", err )
		return nil, err
	end
	addr = addr or "*"
	local server, err = socket_bind( addr, port )
	if err then
		out_error( "server.lua, [", addr, "]:", port, ": ", err )
		return nil, err
	end
	local handler, err = wrapserver( listeners, server, addr, port, pattern, sslctx, _maxclientsperserver ) -- wrap new server socket
	if not handler then
		server:close( )
		return nil, err
	end
	server:settimeout( 0 )
	_readlistlen = addsocket(_readlist, server, _readlistlen)
	_server[ addr..":"..port ] = handler
	_socketlist[ server ] = handler
	out_put( "server.lua: new "..(sslctx and "ssl " or "").."server listener on '[", addr, "]:", port, "'" )
	return handler
end

getserver = function ( addr, port )
	return _server[ addr..":"..port ];
end

removeserver = function( addr, port )
	local handler = _server[ addr..":"..port ]
	if not handler then
		return nil, "no server found on '[" .. addr .. "]:" .. tostring( port ) .. "'"
	end
	handler:close( )
	_server[ addr..":"..port ] = nil
	return true
end

closeall = function( )
	for _, handler in pairs( _socketlist ) do
		handler:close( )
		_socketlist[ _ ] = nil
	end
	_readlistlen = 0
	_sendlistlen = 0
	_timerlistlen = 0
	_server = { }
	_readlist = { }
	_sendlist = { }
	_timerlist = { }
	_socketlist = { }
	--mem_free( )
end

getsettings = function( )
	return	_selecttimeout, _sleeptime, _maxsendlen, _maxreadlen, _checkinterval, _sendtimeout, _readtimeout, _cleanqueue, _maxclientsperserver, _maxsslhandshake
end

changesettings = function( new )
	if type( new ) ~= "table" then
		return nil, "invalid settings table"
	end
	_selecttimeout = tonumber( new.timeout ) or _selecttimeout
	_sleeptime = tonumber( new.sleeptime ) or _sleeptime
	_maxsendlen = tonumber( new.maxsendlen ) or _maxsendlen
	_maxreadlen = tonumber( new.maxreadlen ) or _maxreadlen
	_checkinterval = tonumber( new.checkinterval ) or _checkinterval
	_sendtimeout = tonumber( new.sendtimeout ) or _sendtimeout
	_readtimeout = tonumber( new.readtimeout ) or _readtimeout
	_cleanqueue = new.cleanqueue
	_maxclientsperserver = new._maxclientsperserver or _maxclientsperserver
	_maxsslhandshake = new._maxsslhandshake or _maxsslhandshake
	return true
end

addtimer = function( listener )
	if type( listener ) ~= "function" then
		return nil, "invalid listener function"
	end
	_timerlistlen = _timerlistlen + 1
	_timerlist[ _timerlistlen ] = listener
	return true
end

stats = function( )
	return _readtraffic, _sendtraffic, _readlistlen, _sendlistlen, _timerlistlen
end

local quitting;

setquitting = function (quit)
	quitting = not not quit;
end

loop = function(once) -- this is the main loop of the program
	if quitting then return "quitting"; end
	if once then quitting = "once"; end
	local next_timer_time = math_huge;
	repeat
		local read, write, err = socket_select( _readlist, _sendlist, math_min(_selecttimeout, next_timer_time) )
		for i, socket in ipairs( write ) do -- send data waiting in writequeues
			local handler = _socketlist[ socket ]
			if handler then
				handler.sendbuffer( )
			else
				closesocket( socket )
				out_put "server.lua: found no handler and closed socket (writelist)"	-- this should not happen
			end
		end
		for i, socket in ipairs( read ) do -- receive data
			local handler = _socketlist[ socket ]
			if handler then
				handler.readbuffer( )
			else
				closesocket( socket )
				out_put "server.lua: found no handler and closed socket (readlist)" -- this can happen
			end
		end
		for handler, err in pairs( _closelist ) do
			handler.disconnect( )( handler, err )
			handler:close( true )	 -- forced disconnect
		end
		clean( _closelist )
		_currenttime = luasocket_gettime( )
		if _currenttime - _timer >= math_min(next_timer_time, 1) then
			next_timer_time = math_huge;
			for i = 1, _timerlistlen do
				local t = _timerlist[ i ]( _currenttime ) -- fire timers
				if t then next_timer_time = math_min(next_timer_time, t); end
			end
			_timer = _currenttime
		else
			next_timer_time = next_timer_time - (_currenttime - _timer);
		end
		socket_sleep( _sleeptime ) -- wait some time
		--collectgarbage( )
	until quitting;
	if once and quitting == "once" then quitting = nil; return; end
	return "quitting"
end

step = function ()
	return loop(true);
end

local function get_backend()
	return "select";
end

--// EXPERIMENTAL //--

local wrapclient = function( socket, ip, serverport, listeners, pattern, sslctx )
	local handler = wrapconnection( nil, listeners, socket, ip, serverport, "clientport", pattern, sslctx )
	_socketlist[ socket ] = handler
	if not sslctx then
		_sendlistlen = addsocket(_sendlist, socket, _sendlistlen)
		if listeners.onconnect then
			-- When socket is writeable, call onconnect
			local _sendbuffer = handler.sendbuffer;
			handler.sendbuffer = function ()
				_sendlistlen = removesocket( _sendlist, socket, _sendlistlen );
				handler.sendbuffer = _sendbuffer;
				listeners.onconnect(handler);
				-- If there was data with the incoming packet, handle it now.
				if #handler:bufferqueue() > 0 then
					return _sendbuffer();
				end
			end
		end
	end
	return handler, socket
end

local addclient = function( address, port, listeners, pattern, sslctx )
	local client, err = luasocket.tcp( )
	if err then
		return nil, err
	end
	client:settimeout( 0 )
	_, err = client:connect( address, port )
	if err then -- try again
		local handler = wrapclient( client, address, port, listeners )
	else
		wrapconnection( nil, listeners, client, address, port, "clientport", pattern, sslctx )
	end
end

--// EXPERIMENTAL //--

----------------------------------// BEGIN //--

use "setmetatable" ( _socketlist, { __mode = "k" } )
use "setmetatable" ( _readtimes, { __mode = "k" } )
use "setmetatable" ( _writetimes, { __mode = "k" } )

_timer = luasocket_gettime( )
_starttime = luasocket_gettime( )

addtimer( function( )
		local difftime = os_difftime( _currenttime - _starttime )
		if difftime > _checkinterval then
			_starttime = _currenttime
			for handler, timestamp in pairs( _writetimes ) do
				if os_difftime( _currenttime - timestamp ) > _sendtimeout then
					--_writetimes[ handler ] = nil
					handler.disconnect( )( handler, "send timeout" )
					handler:close( true )	 -- forced disconnect
				end
			end
			for handler, timestamp in pairs( _readtimes ) do
				if os_difftime( _currenttime - timestamp ) > _readtimeout then
					--_readtimes[ handler ] = nil
					handler.disconnect( )( handler, "read timeout" )
					handler:close( )	-- forced disconnect?
				end
			end
		end
	end
)

local function setlogger(new_logger)
	local old_logger = log;
	if new_logger then
		log = new_logger;
	end
	return old_logger;
end

----------------------------------// PUBLIC INTERFACE //--

return {

	addclient = addclient,
	wrapclient = wrapclient,
	
	loop = loop,
	link = link,
	step = step,
	stats = stats,
	closeall = closeall,
	addtimer = addtimer,
	addserver = addserver,
	getserver = getserver,
	setlogger = setlogger,
	getsettings = getsettings,
	setquitting = setquitting,
	removeserver = removeserver,
	get_backend = get_backend,
	changesettings = changesettings,
}
 end)
package.preload['util.xmppstream'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--


local lxp = require "lxp";
local st = require "util.stanza";
local stanza_mt = st.stanza_mt;

local tostring = tostring;
local t_insert = table.insert;
local t_concat = table.concat;
local t_remove = table.remove;
local setmetatable = setmetatable;

local default_log = require "util.logger".init("xmppstream");

-- COMPAT: w/LuaExpat 1.1.0
local lxp_supports_doctype = pcall(lxp.new, { StartDoctypeDecl = false });

if not lxp_supports_doctype then
	default_log("warn", "The version of LuaExpat on your system leaves Prosody "
		.."vulnerable to denial-of-service attacks. You should upgrade to "
		.."LuaExpat 1.1.1 or higher as soon as possible. See "
		.."http://prosody.im/doc/depends#luaexpat for more information.");
end

local error = error;

module "xmppstream"

local new_parser = lxp.new;

local ns_prefixes = {
	["http://www.w3.org/XML/1998/namespace"] = "xml";
};

local xmlns_streams = "http://etherx.jabber.org/streams";

local ns_separator = "\1";
local ns_pattern = "^([^"..ns_separator.."]*)"..ns_separator.."?(.*)$";

_M.ns_separator = ns_separator;
_M.ns_pattern = ns_pattern;

function new_sax_handlers(session, stream_callbacks)
	local xml_handlers = {};
	
	local log = session.log or default_log;
	
	local cb_streamopened = stream_callbacks.streamopened;
	local cb_streamclosed = stream_callbacks.streamclosed;
	local cb_error = stream_callbacks.error or function(session, e) error("XML stream error: "..tostring(e)); end;
	local cb_handlestanza = stream_callbacks.handlestanza;
	
	local stream_ns = stream_callbacks.stream_ns or xmlns_streams;
	local stream_tag = stream_callbacks.stream_tag or "stream";
	if stream_ns ~= "" then
		stream_tag = stream_ns..ns_separator..stream_tag;
	end
	local stream_error_tag = stream_ns..ns_separator..(stream_callbacks.error_tag or "error");
	
	local stream_default_ns = stream_callbacks.default_ns;
	
	local stack = {};
	local chardata, stanza = {};
	local non_streamns_depth = 0;
	function xml_handlers:StartElement(tagname, attr)
		if stanza and #chardata > 0 then
			-- We have some character data in the buffer
			t_insert(stanza, t_concat(chardata));
			chardata = {};
		end
		local curr_ns,name = tagname:match(ns_pattern);
		if name == "" then
			curr_ns, name = "", curr_ns;
		end

		if curr_ns ~= stream_default_ns or non_streamns_depth > 0 then
			attr.xmlns = curr_ns;
			non_streamns_depth = non_streamns_depth + 1;
		end
		
		-- FIXME !!!!!
		for i=1,#attr do
			local k = attr[i];
			attr[i] = nil;
			local ns, nm = k:match(ns_pattern);
			if nm ~= "" then
				ns = ns_prefixes[ns];
				if ns then
					attr[ns..":"..nm] = attr[k];
					attr[k] = nil;
				end
			end
		end
		
		if not stanza then --if we are not currently inside a stanza
			if session.notopen then
				if tagname == stream_tag then
					non_streamns_depth = 0;
					if cb_streamopened then
						cb_streamopened(session, attr);
					end
				else
					-- Garbage before stream?
					cb_error(session, "no-stream");
				end
				return;
			end
			if curr_ns == "jabber:client" and name ~= "iq" and name ~= "presence" and name ~= "message" then
				cb_error(session, "invalid-top-level-element");
			end
			
			stanza = setmetatable({ name = name, attr = attr, tags = {} }, stanza_mt);
		else -- we are inside a stanza, so add a tag
			t_insert(stack, stanza);
			local oldstanza = stanza;
			stanza = setmetatable({ name = name, attr = attr, tags = {} }, stanza_mt);
			t_insert(oldstanza, stanza);
			t_insert(oldstanza.tags, stanza);
		end
	end
	function xml_handlers:CharacterData(data)
		if stanza then
			t_insert(chardata, data);
		end
	end
	function xml_handlers:EndElement(tagname)
		if non_streamns_depth > 0 then
			non_streamns_depth = non_streamns_depth - 1;
		end
		if stanza then
			if #chardata > 0 then
				-- We have some character data in the buffer
				t_insert(stanza, t_concat(chardata));
				chardata = {};
			end
			-- Complete stanza
			if #stack == 0 then
				if tagname ~= stream_error_tag then
					cb_handlestanza(session, stanza);
				else
					cb_error(session, "stream-error", stanza);
				end
				stanza = nil;
			else
				stanza = t_remove(stack);
			end
		else
			if tagname == stream_tag then
				if cb_streamclosed then
					cb_streamclosed(session);
				end
			else
				local curr_ns,name = tagname:match(ns_pattern);
				if name == "" then
					curr_ns, name = "", curr_ns;
				end
				cb_error(session, "parse-error", "unexpected-element-close", name);
			end
			stanza, chardata = nil, {};
			stack = {};
		end
	end

	local function restricted_handler(parser)
		cb_error(session, "parse-error", "restricted-xml", "Restricted XML, see RFC 6120 section 11.1.");
		if not parser.stop or not parser:stop() then
			error("Failed to abort parsing");
		end
	end
	
	if lxp_supports_doctype then
		xml_handlers.StartDoctypeDecl = restricted_handler;
	end
	xml_handlers.Comment = restricted_handler;
	xml_handlers.ProcessingInstruction = restricted_handler;
	
	local function reset()
		stanza, chardata = nil, {};
		stack = {};
	end
	
	local function set_session(stream, new_session)
		session = new_session;
		log = new_session.log or default_log;
	end
	
	return xml_handlers, { reset = reset, set_session = set_session };
end

function new(session, stream_callbacks)
	local handlers, meta = new_sax_handlers(session, stream_callbacks);
	local parser = new_parser(handlers, ns_separator);
	local parse = parser.parse;

	return {
		reset = function ()
			parser = new_parser(handlers, ns_separator);
			parse = parser.parse;
			meta.reset();
		end,
		feed = function (self, data)
			return parse(parser, data);
		end,
		set_session = meta.set_session;
	};
end

return _M;
 end)
package.preload['util.jid'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--



local match = string.match;
local nodeprep = require "util.encodings".stringprep.nodeprep;
local nameprep = require "util.encodings".stringprep.nameprep;
local resourceprep = require "util.encodings".stringprep.resourceprep;

module "jid"

local function _split(jid)
	if not jid then return; end
	local node, nodepos = match(jid, "^([^@/]+)@()");
	local host, hostpos = match(jid, "^([^@/]+)()", nodepos)
	if node and not host then return nil, nil, nil; end
	local resource = match(jid, "^/(.+)$", hostpos);
	if (not host) or ((not resource) and #jid >= hostpos) then return nil, nil, nil; end
	return node, host, resource;
end
split = _split;

function bare(jid)
	local node, host = _split(jid);
	if node and host then
		return node.."@"..host;
	end
	return host;
end

local function _prepped_split(jid)
	local node, host, resource = _split(jid);
	if host then
		host = nameprep(host);
		if not host then return; end
		if node then
			node = nodeprep(node);
			if not node then return; end
		end
		if resource then
			resource = resourceprep(resource);
			if not resource then return; end
		end
		return node, host, resource;
	end
end
prepped_split = _prepped_split;

function prep(jid)
	local node, host, resource = _prepped_split(jid);
	if host then
		if node then
			host = node .. "@" .. host;
		end
		if resource then
			host = host .. "/" .. resource;
		end
	end
	return host;
end

function join(node, host, resource)
	if node and host and resource then
		return node.."@"..host.."/"..resource;
	elseif node and host then
		return node.."@"..host;
	elseif host and resource then
		return host.."/"..resource;
	elseif host then
		return host;
	end
	return nil; -- Invalid JID
end

function compare(jid, acl)
	-- compare jid to single acl rule
	-- TODO compare to table of rules?
	local jid_node, jid_host, jid_resource = _split(jid);
	local acl_node, acl_host, acl_resource = _split(acl);
	if ((acl_node ~= nil and acl_node == jid_node) or acl_node == nil) and
		((acl_host ~= nil and acl_host == jid_host) or acl_host == nil) and
		((acl_resource ~= nil and acl_resource == jid_resource) or acl_resource == nil) then
		return true
	end
	return false
end

return _M;
 end)
package.preload['util.events'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--


local pairs = pairs;
local t_insert = table.insert;
local t_sort = table.sort;
local setmetatable = setmetatable;
local next = next;

module "events"

function new()
	local handlers = {};
	local event_map = {};
	local function _rebuild_index(handlers, event)
		local _handlers = event_map[event];
		if not _handlers or next(_handlers) == nil then return; end
		local index = {};
		for handler in pairs(_handlers) do
			t_insert(index, handler);
		end
		t_sort(index, function(a, b) return _handlers[a] > _handlers[b]; end);
		handlers[event] = index;
		return index;
	end;
	setmetatable(handlers, { __index = _rebuild_index });
	local function add_handler(event, handler, priority)
		local map = event_map[event];
		if map then
			map[handler] = priority or 0;
		else
			map = {[handler] = priority or 0};
			event_map[event] = map;
		end
		handlers[event] = nil;
	end;
	local function remove_handler(event, handler)
		local map = event_map[event];
		if map then
			map[handler] = nil;
			handlers[event] = nil;
			if next(map) == nil then
				event_map[event] = nil;
			end
		end
	end;
	local function add_handlers(handlers)
		for event, handler in pairs(handlers) do
			add_handler(event, handler);
		end
	end;
	local function remove_handlers(handlers)
		for event, handler in pairs(handlers) do
			remove_handler(event, handler);
		end
	end;
	local function fire_event(event, ...)
		local h = handlers[event];
		if h then
			for i=1,#h do
				local ret = h[i](...);
				if ret ~= nil then return ret; end
			end
		end
	end;
	return {
		add_handler = add_handler;
		remove_handler = remove_handler;
		add_handlers = add_handlers;
		remove_handlers = remove_handlers;
		fire_event = fire_event;
		_handlers = handlers;
		_event_map = event_map;
	};
end

return _M;
 end)
package.preload['util.dataforms'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local setmetatable = setmetatable;
local pairs, ipairs = pairs, ipairs;
local tostring, type = tostring, type;
local t_concat = table.concat;
local st = require "util.stanza";

module "dataforms"

local xmlns_forms = 'jabber:x:data';

local form_t = {};
local form_mt = { __index = form_t };

function new(layout)
	return setmetatable(layout, form_mt);
end

function form_t.form(layout, data, formtype)
	local form = st.stanza("x", { xmlns = xmlns_forms, type = formtype or "form" });
	if layout.title then
		form:tag("title"):text(layout.title):up();
	end
	if layout.instructions then
		form:tag("instructions"):text(layout.instructions):up();
	end
	for n, field in ipairs(layout) do
		local field_type = field.type or "text-single";
		-- Add field tag
		form:tag("field", { type = field_type, var = field.name, label = field.label });

		local value = (data and data[field.name]) or field.value;
		
		if value then
			-- Add value, depending on type
			if field_type == "hidden" then
				if type(value) == "table" then
					-- Assume an XML snippet
					form:tag("value")
						:add_child(value)
						:up();
				else
					form:tag("value"):text(tostring(value)):up();
				end
			elseif field_type == "boolean" then
				form:tag("value"):text((value and "1") or "0"):up();
			elseif field_type == "fixed" then
				
			elseif field_type == "jid-multi" then
				for _, jid in ipairs(value) do
					form:tag("value"):text(jid):up();
				end
			elseif field_type == "jid-single" then
				form:tag("value"):text(value):up();
			elseif field_type == "text-single" or field_type == "text-private" then
				form:tag("value"):text(value):up();
			elseif field_type == "text-multi" then
				-- Split into multiple <value> tags, one for each line
				for line in value:gmatch("([^\r\n]+)\r?\n*") do
					form:tag("value"):text(line):up();
				end
			elseif field_type == "list-single" then
				local has_default = false;
				if type(value) == "string" then
					form:tag("value"):text(value):up();
				else
					for _, val in ipairs(value) do
						if type(val) == "table" then
							form:tag("option", { label = val.label }):tag("value"):text(val.value):up():up();
							if val.default and (not has_default) then
								form:tag("value"):text(val.value):up();
								has_default = true;
							end
						else
							form:tag("option", { label= val }):tag("value"):text(tostring(val)):up():up();
						end
					end
				end
			elseif field_type == "list-multi" then
				for _, val in ipairs(value) do
					if type(val) == "table" then
						form:tag("option", { label = val.label }):tag("value"):text(val.value):up():up();
						if val.default then
							form:tag("value"):text(val.value):up();
						end
					else
						form:tag("option", { label= val }):tag("value"):text(tostring(val)):up():up();
					end
				end
			end
		end
		
		if field.required then
			form:tag("required"):up();
		end
		
		-- Jump back up to list of fields
		form:up();
	end
	return form;
end

local field_readers = {};

function form_t.data(layout, stanza)
	local data = {};
	
	for field_tag in stanza:childtags() do
		local field_type;
		for n, field in ipairs(layout) do
			if field.name == field_tag.attr.var then
				field_type = field.type;
				break;
			end
		end
		
		local reader = field_readers[field_type];
		if reader then
			data[field_tag.attr.var] = reader(field_tag);
		end
		
	end
	return data;
end

field_readers["text-single"] = 
	function (field_tag)
		local value = field_tag:child_with_name("value");
		if value then
			return value[1];
		end
	end

field_readers["text-private"] = 
	field_readers["text-single"];

field_readers["jid-single"] =
	field_readers["text-single"];

field_readers["jid-multi"] = 
	function (field_tag)
		local result = {};
		for value_tag in field_tag:childtags() do
			if value_tag.name == "value" then
				result[#result+1] = value_tag[1];
			end
		end
		return result;
	end

field_readers["text-multi"] = 
	function (field_tag)
		local result = {};
		for value_tag in field_tag:childtags() do
			if value_tag.name == "value" then
				result[#result+1] = value_tag[1];
			end
		end
		return t_concat(result, "\n");
	end

field_readers["list-single"] =
	field_readers["text-single"];

field_readers["list-multi"] =
	function (field_tag)
		local result = {};
		for value_tag in field_tag:childtags() do
			if value_tag.name == "value" then
				result[#result+1] = value_tag[1];
			end
		end
		return result;
	end

field_readers["boolean"] = 
	function (field_tag)
		local value = field_tag:child_with_name("value");
		if value then
			if value[1] == "1" or value[1] == "true" then
				return true;
			else
				return false;
			end
		end		
	end

field_readers["hidden"] = 
	function (field_tag)
		local value = field_tag:child_with_name("value");
		if value then
			return value[1];
		end
	end
	
return _M;


--[=[

Layout:
{

	title = "MUC Configuration",
	instructions = [[Use this form to configure options for this MUC room.]],

	{ name = "FORM_TYPE", type = "hidden", required = true };
	{ name = "field-name", type = "field-type", required = false };
}


--]=]
 end)
package.preload['verse.plugins.tls'] = (function (...)
local xmlns_tls = "urn:ietf:params:xml:ns:xmpp-tls";

function verse.plugins.tls(stream)
	local function handle_features(features_stanza)
		if stream.authenticated then return; end
		if features_stanza:get_child("starttls", xmlns_tls) and stream.conn.starttls then
			stream:debug("Negotiating TLS...");
			stream:send(verse.stanza("starttls", { xmlns = xmlns_tls }));
			return true;
		elseif not stream.conn.starttls and not stream.secure then
			stream:warn("SSL libary (LuaSec) not loaded, so TLS not available");
		elseif not stream.secure then
			stream:debug("Server doesn't offer TLS :(");
		end
	end
	local function handle_tls(tls_status)
		if tls_status.name == "proceed" then
			stream:debug("Server says proceed, handshake starting...");
			stream.conn:starttls({mode="client", protocol="sslv23", options="no_sslv2"}, true);
		end
	end
	local function handle_status(new_status)
		if new_status == "ssl-handshake-complete" then
			stream.secure = true;
			stream:debug("Re-opening stream...");
			stream:reopen();
		end
	end
	stream:hook("stream-features", handle_features, 400);
	stream:hook("stream/"..xmlns_tls, handle_tls);
	stream:hook("status", handle_status, 400);
	
	return true;
end
 end)
package.preload['verse.plugins.sasl'] = (function (...)
local base64 = require "mime".b64;
local xmlns_sasl = "urn:ietf:params:xml:ns:xmpp-sasl";

function verse.plugins.sasl(stream)
	local function handle_features(features_stanza)
		if stream.authenticated then return; end
		stream:debug("Authenticating with SASL...");
		local initial_data = base64("\0"..stream.username.."\0"..stream.password);
	
		--stream.sasl_state, initial_data = sasl_new({"PLAIN"}, stream.username, stream.password, stream.jid);
		
		stream:debug("Selecting PLAIN mechanism...");
		local auth_stanza = verse.stanza("auth", { xmlns = xmlns_sasl, mechanism = "PLAIN" });
		if initial_data then
			auth_stanza:text(initial_data);
		end
		stream:send(auth_stanza);
		return true;
	end
	
	local function handle_sasl(sasl_stanza)
		if sasl_stanza.name == "success" then
			stream.authenticated = true;
			stream:event("authentication-success");
		elseif sasl_stanza.name == "failure" then
			local err = sasl_stanza.tags[1];
			stream:event("authentication-failure", { condition = err.name });
		end
		stream:reopen();
		return true;
	end
	
	stream:hook("stream-features", handle_features, 300);
	stream:hook("stream/"..xmlns_sasl, handle_sasl);
	
	return true;
end

 end)
package.preload['verse.plugins.bind'] = (function (...)
local xmlns_bind = "urn:ietf:params:xml:ns:xmpp-bind";

function verse.plugins.bind(stream)
	local function handle_features(features)
		if stream.bound then return; end
		stream:debug("Binding resource...");
		stream:send_iq(verse.iq({ type = "set" }):tag("bind", {xmlns=xmlns_bind}):tag("resource"):text(stream.resource),
			function (reply)
				if reply.attr.type == "result" then
					local result_jid = reply
						:get_child("bind", xmlns_bind)
							:get_child("jid")
								:get_text();
					stream.username, stream.host, stream.resource = jid.split(result_jid);
					stream.jid, stream.bound = result_jid, true;
					stream:event("bind-success", { jid = result_jid });
				elseif reply.attr.type == "error" then
					local err = reply:child_with_name("error");
					local type, condition, text = reply:get_error();
					stream:event("bind-failure", { error = condition, text = text, type = type });
				end
			end);
	end
	stream:hook("stream-features", handle_features, 200);
	return true;
end

 end)
package.preload['verse.plugins.legacy'] = (function (...)
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
 end)
package.preload['verse.plugins.pubsub'] = (function (...)
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
 end)
package.preload['verse.plugins.version'] = (function (...)
local xmlns_version = "jabber:iq:version";

local function set_version(self, version_info)
	self.name = version_info.name;
	self.version = version_info.version;
	self.platform = version_info.platform;
end

function verse.plugins.version(stream)
	stream.version = { set = set_version };
	stream:hook("iq/"..xmlns_version, function (stanza)
		if stanza.attr.type ~= "get" then return; end
		local reply = verse.reply(stanza)
			:tag("query", { xmlns = xmlns_version });
		if stream.version.name then
			reply:tag("name"):text(tostring(stream.version.name)):up();
		end
		if stream.version.version then
			reply:tag("version"):text(tostring(stream.version.version)):up()
		end
		if stream.version.platform then
			reply:tag("os"):text(stream.version.platform);
		end
		stream:send(reply);
		return true;
	end);
	
	function stream:query_version(target_jid, callback)
		callback = callback or function (version) return stream:event("version/response", version); end
		stream:send_iq(verse.iq({ type = "get", to = target_jid })
			:tag("query", { xmlns = xmlns_version }), 
			function (reply)
				local query = reply:get_child("query", xmlns_version);
				if reply.attr.type == "result" then
					local name = query:get_child("name");
					local version = query:get_child("version");
					local os = query:get_child("os");
					callback({
						name = name and name:get_text() or nil;
						version = version and version:get_text() or nil;
						platform = os and os:get_text() or nil;
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
 end)
package.preload['verse.plugins.ping'] = (function (...)
local xmlns_ping = "urn:xmpp:ping";

function verse.plugins.ping(stream)
	function stream:ping(jid, callback)
		local t = socket.gettime();
		stream:send_iq(verse.iq{ to = jid, type = "get" }:tag("ping", { xmlns = xmlns_ping }), 
			function (reply)
				if reply.attr.type == "error" then
					local type, condition, text = reply:get_error();
					if condition ~= "service-unavailable" and condition ~= "feature-not-implemented" then
						callback(nil, jid, { type = type, condition = condition, text = text });
						return;
					end
				end
				callback(socket.gettime()-t, jid);
			end);
	end
	return true;
end
 end)
package.preload['verse.plugins.session'] = (function (...)
local xmlns_session = "urn:ietf:params:xml:ns:xmpp-session";

function verse.plugins.session(stream)
	
	local function handle_features(features)
		local session_feature = features:get_child("session", xmlns_session);
		if session_feature and not session_feature:get_child("optional") then
			local function handle_binding(jid)
				stream:debug("Establishing Session...");
				stream:send_iq(verse.iq({ type = "set" }):tag("session", {xmlns=xmlns_session}),
					function (reply)
						if reply.attr.type == "result" then
							stream:event("session-success");
						elseif reply.attr.type == "error" then
							local err = reply:child_with_name("error");
							local type, condition, text = reply:get_error();
							stream:event("session-failure", { error = condition, text = text, type = type });
						end
					end);
				return true;
			end
			stream:hook("bind-success", handle_binding);
		end
	end
	stream:hook("stream-features", handle_features);
	
	return true;
end
 end)
package.preload['verse.plugins.compression'] = (function (...)
-- Copyright (C) 2009-2010 Matthew Wild
-- Copyright (C) 2009-2010 Tobias Markmann
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local zlib = require "zlib";

local xmlns_compression_feature = "http://jabber.org/features/compress"
local xmlns_compression_protocol = "http://jabber.org/protocol/compress"
local xmlns_stream = "http://etherx.jabber.org/streams";

local compression_level = 9;

-- returns either nil or a fully functional ready to use inflate stream
local function get_deflate_stream(session)
	local status, deflate_stream = pcall(zlib.deflate, compression_level);
	if status == false then
		local error_st = verse.stanza("failure", {xmlns=xmlns_compression_protocol}):tag("setup-failed");
		session:send(error_st);
		session:error("Failed to create zlib.deflate filter: %s", tostring(deflate_stream));
		return
	end
	return deflate_stream
end

-- returns either nil or a fully functional ready to use inflate stream
local function get_inflate_stream(session)
	local status, inflate_stream = pcall(zlib.inflate);
	if status == false then
		local error_st = verse.stanza("failure", {xmlns=xmlns_compression_protocol}):tag("setup-failed");
		session:send(error_st);
		session:error("Failed to create zlib.inflate filter: %s", tostring(inflate_stream));
		return
	end
	return inflate_stream
end

-- setup compression for a stream
local function setup_compression(session, deflate_stream)
	function session:send(t)
			--TODO: Better code injection in the sending process
			local status, compressed, eof = pcall(deflate_stream, tostring(t), 'sync');
			if status == false then
				session:close({
					condition = "undefined-condition";
					text = compressed;
					extra = verse.stanza("failure", {xmlns=xmlns_compression_protocol}):tag("processing-failed");
				});
				session:warn("Compressed send failed: %s", tostring(compressed));
				return;
			end
			session.conn:write(compressed);
		end;	
end

-- setup decompression for a stream
local function setup_decompression(session, inflate_stream)
	local old_data = session.data
	session.data = function(conn, data)
			session:debug("Decompressing data...");
			local status, decompressed, eof = pcall(inflate_stream, data);
			if status == false then
				session:close({
					condition = "undefined-condition";
					text = decompressed;
					extra = verse.stanza("failure", {xmlns=xmlns_compression_protocol}):tag("processing-failed");
				});
				stream:warn("%s", tostring(decompressed));
				return;
			end
			return old_data(conn, decompressed);
		end;
end

function verse.plugins.compression(stream)
	local function handle_features(features)
		if not stream.compressed then
			-- does remote server support compression?
			local comp_st = features:child_with_name("compression");
			if comp_st then
				-- do we support the mechanism
				for a in comp_st:children() do
					local algorithm = a[1]
					if algorithm == "zlib" then
						stream:send(verse.stanza("compress", {xmlns=xmlns_compression_protocol}):tag("method"):text("zlib"))
						stream:debug("Enabled compression using zlib.")
						return true;
					end
				end
				session:debug("Remote server supports no compression algorithm we support.")
			end
		end
	end
	local function handle_compressed(stanza)
		if stanza.name == "compressed" then
			stream:debug("Activating compression...")

			-- create deflate and inflate streams
			local deflate_stream = get_deflate_stream(stream);
			if not deflate_stream then return end
			
			local inflate_stream = get_inflate_stream(stream);
			if not inflate_stream then return end
			
			-- setup compression for stream.w
			setup_compression(stream, deflate_stream);
				
			-- setup decompression for stream.data
			setup_decompression(stream, inflate_stream);
			
			stream.compressed = true;
			stream:reopen();
		elseif stanza.name == "failure" then
			stream:warn("Failed to establish compression");
		end
	end
	stream:hook("stream-features", handle_features, 250);
	stream:hook("stream/"..xmlns_compression_protocol, handle_compressed);
end
 end)
package.preload['verse.plugins.blocking'] = (function (...)
local xmlns_blocking = "urn:xmpp:blocking";

function verse.plugins.blocking(stream)
	-- FIXME: Disco
	stream.blocking = {};
	function stream.blocking:block_jid(jid, callback)
		stream:send_iq(verse.iq{type="set"}
			:tag("block", { xmlns = xmlns_blocking })
				:tag("item", { jid = jid })
			, function () return callback and callback(true); end
			, function () return callback and callback(false); end
		);
	end
	function stream.blocking:unblock_jid(jid, callback)
		stream:send_iq(verse.iq{type="set"}
			:tag("unblock", { xmlns = xmlns_blocking })
				:tag("item", { jid = jid })
			, function () return callback and callback(true); end
			, function () return callback and callback(false); end
		);
	end
	function stream.blocking:unblock_all_jids(callback)
		stream:send_iq(verse.iq{type="set"}
			:tag("unblock", { xmlns = xmlns_blocking })
			, function () return callback and callback(true); end
			, function () return callback and callback(false); end
		);
	end
	function stream.blocking:get_blocked_jids(callback)
		stream:send_iq(verse.iq{type="get"}
			:tag("blocklist", { xmlns = xmlns_blocking })
			, function (result)
				local list = result:get_child("blocklist", xmlns_blocking);
				if not list then return callback and callback(false); end
				local jids = {};
				for item in list:childtags() do
					jids[#jids+1] = item.attr.jid;
				end
				return callback and callback(jids);
			  end
			, function (result) return callback and callback(false); end
		);
	end
end
 end)
package.preload['verse.plugins.proxy65'] = (function (...)
local events = require "util.events";
local uuid = require "util.uuid";
local sha1 = require "util.sha1";

local proxy65_mt = {};
proxy65_mt.__index = proxy65_mt;

local xmlns_bytestreams = "http://jabber.org/protocol/bytestreams";

local negotiate_socks5;

function verse.plugins.proxy65(stream)
	stream.proxy65 = setmetatable({ stream = stream }, proxy65_mt);
	stream.proxy65.available_streamhosts = {};
	local outstanding_proxies = 0;
	stream:hook("disco/service-discovered/proxy", function (service)
		-- Fill list with available proxies
		if service.type == "bytestreams" then
			outstanding_proxies = outstanding_proxies + 1;
			stream:send_iq(verse.iq({ to = service.jid, type = "get" })
				:tag("query", { xmlns = xmlns_bytestreams }), function (result)
				
				outstanding_proxies = outstanding_proxies - 1;
				if result.attr.type == "result" then
					local streamhost = result:get_child("query", xmlns_bytestreams)
						:get_child("streamhost").attr;
					
					stream.proxy65.available_streamhosts[streamhost.jid] = {
						jid = streamhost.jid;
						host = streamhost.host;
						port = tonumber(streamhost.port);
					};
				end
				if outstanding_proxies == 0 then
					stream:event("proxy65/discovered-proxies", stream.proxy65.available_streamhosts);
				end
			end);
		end
	end);
	stream:hook("iq/"..xmlns_bytestreams, function (request)
		local conn = verse.new(nil, {
			initiator_jid = request.attr.from,
			streamhosts = {},
			current_host = 0;
		});
		
		-- Parse hosts from request
		for tag in request.tags[1]:childtags() do
			if tag.name == "streamhost" then
				table.insert(conn.streamhosts, tag.attr);	
			end
		end
		
		--Attempt to connect to the next host
		local function attempt_next_streamhost()
			-- First connect, or the last connect failed
			if conn.current_host < #conn.streamhosts then
				conn.current_host = conn.current_host + 1;
				conn:connect(
					conn.streamhosts[conn.current_host].host,
					conn.streamhosts[conn.current_host].port
				);
				negotiate_socks5(stream, conn, request.tags[1].attr.sid, request.attr.from, stream.jid);
				return true; -- Halt processing of disconnected event
			end
			-- All streamhosts tried, none successful
			conn:unhook("disconnected", attempt_next_streamhost);
			stream:send(verse.error_reply(request, "cancel", "item-not-found"));
			-- Let disconnected event fall through to user handlers...
		end
		
		function conn:accept()
			conn:hook("disconnected", attempt_next_streamhost, 100);
			-- When this event fires, we're connected to a streamhost
			conn:hook("connected", function ()
				conn:unhook("disconnected", attempt_next_streamhost);
				-- Send XMPP success notification
				local reply = verse.reply(request)
					:tag("query", request.tags[1].attr)
					:tag("streamhost-used", { jid = conn.streamhosts[conn.current_host].jid });
				stream:send(reply);
			end, 100);
			attempt_next_streamhost();
		end
		function conn:refuse()
			-- FIXME: XMPP refused reply
		end
		stream:event("proxy65/request", conn);
	end);
end

function proxy65_mt:new(target_jid, proxies)
	local conn = verse.new(nil, {
		target_jid = target_jid;
		bytestream_sid = uuid.generate();
	});
	
	local request = verse.iq{type="set", to = target_jid}
		:tag("query", { xmlns = xmlns_bytestreams, mode = "tcp", sid = conn.bytestream_sid });
	for _, proxy in ipairs(proxies or self.proxies) do
		request:tag("streamhost", proxy):up();
	end
	
	
	self.stream:send_iq(request, function (reply)
		if reply.attr.type == "error" then
			local type, condition, text = reply:get_error();
			conn:event("connection-failed", { conn = conn, type = type, condition = condition, text = text });
		else
			-- Target connected to streamhost, connect ourselves
			local streamhost_used = reply.tags[1]:get_child("streamhost-used");
			if not streamhost_used then
				--FIXME: Emit error
			end
			conn.streamhost_jid = streamhost_used.attr.jid;
			local host, port;
			for _, proxy in ipairs(proxies or self.proxies) do
				if proxy.jid == conn.streamhost_jid then
					host, port = proxy.host, proxy.port;
					break;
				end
			end
			if not (host and port) then
				--FIXME: Emit error
			end
			
			conn:connect(host, port);

			local function handle_proxy_connected()
				conn:unhook("connected", handle_proxy_connected);
				-- Both of us connected, tell proxy to activate connection
				local request = verse.iq{to = conn.streamhost_jid, type="set"}
					:tag("query", { xmlns = xmlns_bytestreams, sid = conn.bytestream_sid })
						:tag("activate"):text(target_jid);
				self.stream:send_iq(request, function (reply)
					if reply.attr.type == "result" then
						-- Connection activated, ready to use
						conn:event("connected", conn);
					else
						--FIXME: Emit error
					end
				end);
				return true;
			end
			conn:hook("connected", handle_proxy_connected, 100);

			negotiate_socks5(self.stream, conn, conn.bytestream_sid, self.stream.jid, target_jid);
		end
	end);
	return conn;
end

function negotiate_socks5(stream, conn, sid, requester_jid, target_jid)
	local hash = sha1.sha1(sid..requester_jid..target_jid);
	local function suppress_connected()
		conn:unhook("connected", suppress_connected);
		return true;
	end
	local function receive_connection_response(data)
		conn:unhook("incoming-raw", receive_connection_response);
		
		if data:sub(1, 2) ~= "\005\000" then
			return conn:event("error", "connection-failure");
		end
		conn:event("connected");
		return true;
	end
	local function receive_auth_response(data)
		conn:unhook("incoming-raw", receive_auth_response);
		if data ~= "\005\000" then -- SOCKSv5; "NO AUTHENTICATION"
			-- Server is not SOCKSv5, or does not allow no auth
			local err = "version-mismatch";
			if data:sub(1,1) == "\005" then
				err = "authentication-failure";
			end
			return conn:event("error", err);
		end
		-- Request SOCKS5 connection
		conn:send(string.char(0x05, 0x01, 0x00, 0x03, #hash)..hash.."\0\0"); --FIXME: Move to "connected"?
		conn:hook("incoming-raw", receive_connection_response, 100);
		return true;
	end
	conn:hook("connected", suppress_connected, 200);
	conn:hook("incoming-raw", receive_auth_response, 100);
	conn:send("\005\001\000"); -- SOCKSv5; 1 mechanism; "NO AUTHENTICATION"
end
 end)
package.preload['verse.plugins.jingle'] = (function (...)
local sha1 = require "util.sha1".sha1;
local timer = require "util.timer";
local uuid_generate = require "util.uuid".generate;

local xmlns_jingle = "urn:xmpp:jingle:1";
local xmlns_jingle_errors = "urn:xmpp:jingle:errors:1";

local jingle_mt = {};
jingle_mt.__index = jingle_mt;

local registered_transports = {};
local registered_content_types = {};

function verse.plugins.jingle(stream)
	stream:hook("ready", function ()
		stream:add_disco_feature(xmlns_jingle);
	end, 10);
	
	function stream:jingle(to)
		return verse.eventable(setmetatable(base or {
			role = "initiator";
			peer = to;
			sid = uuid_generate();
			stream = stream;
		}, jingle_mt));
	end
	
	function stream:register_jingle_transport(transport)
		-- transport is a function that receives a
		-- <transport> element, and returns a connection
		-- We wait for 'connected' on that connection,
		-- and use :send() and 'incoming-raw'.
	end
	
	function stream:register_jingle_content_type(content)
		-- Call content() for every 'incoming-raw'?
		-- I think content() returns the object we return
		-- on jingle:accept()
	end
	
	local function handle_incoming_jingle(stanza)
		local jingle_tag = stanza:get_child("jingle", xmlns_jingle);
		local sid = jingle_tag.attr.sid;
		local action = jingle_tag.attr.action;
		local result = stream:event("jingle/"..sid, stanza);
		if result == true then
			-- Ack
			stream:send(verse.reply(stanza));
			return true;
		end
		-- No existing Jingle object handled this action, our turn...
		if action ~= "session-initiate" then
			-- Trying to send a command to a session we don't know
			local reply = verse.error_reply(stanza, "cancel", "item-not-found")
				:tag("unknown-session", { xmlns = xmlns_jingle_errors }):up();
			stream:send(reply);
			return;
		end
		
		-- Ok, session-initiate, new session
		
		-- Create new Jingle object
		local sid = jingle_tag.attr.sid;
		
		local jingle = verse.eventable{
			role = "receiver";
			peer = stanza.attr.from;
			sid = sid;
			stream = stream;
		};
		
		setmetatable(jingle, jingle_mt);
		
		local content_tag;
		local content, transport;
		for tag in jingle_tag:childtags() do
			if tag.name == "content" and tag.attr.xmlns == xmlns_jingle then
			 	local description_tag = tag:child_with_name("description");
			 	local description_xmlns = description_tag.attr.xmlns;
			 	if description_xmlns then
			 		local desc_handler = stream:event("jingle/content/"..description_xmlns, jingle, description_tag);
			 		if desc_handler then
			 			content = desc_handler;
			 		end
			 	end
				
				local transport_tag = tag:child_with_name("transport");
				local transport_xmlns = transport_tag.attr.xmlns;
				
				transport = stream:event("jingle/transport/"..transport_xmlns, jingle, transport_tag);
				if content and transport then
					content_tag = tag;
					break;
				end
			end
		end
		if not content then
			-- FIXME: Fail, no content
			stream:send(verse.error_reply(stanza, "cancel", "feature-not-implemented", "The specified content is not supported"));
			return;
		end
		
		if not transport then
			-- FIXME: Refuse session, no transport
			stream:send(verse.error_reply(stanza, "cancel", "feature-not-implemented", "The specified transport is not supported"));
			return;
		end
		
		stream:send(verse.reply(stanza));
		
		jingle.content_tag = content_tag;
		jingle.creator, jingle.name = content_tag.attr.creator, content_tag.attr.name;
		jingle.content, jingle.transport = content, transport;
		
		function jingle:decline()
			-- FIXME: Decline session
		end
		
		stream:hook("jingle/"..sid, function (stanza)
			if stanza.attr.from ~= jingle.peer then
				return false;
			end
			local jingle_tag = stanza:get_child("jingle", xmlns_jingle);
			return jingle:handle_command(jingle_tag);
		end);
		
		stream:event("jingle", jingle);
		return true;
	end
	
	function jingle_mt:handle_command(jingle_tag)
		local action = jingle_tag.attr.action;
		stream:debug("Handling Jingle command: %s", action);
		if action == "session-terminate" then
			self:destroy();
		elseif action == "session-accept" then
			-- Yay!
			self:handle_accepted(jingle_tag);
		elseif action == "transport-info" then
			stream:debug("Handling transport-info");
			self.transport:info_received(jingle_tag);
		elseif action == "transport-replace" then
			-- FIXME: Used for IBB fallback
			stream:error("Peer wanted to swap transport, not implemented");
		else
			-- FIXME: Reply unhandled command
			stream:warn("Unhandled Jingle command: %s", action);
			return nil;
		end
		return true;
	end

	function jingle_mt:send_command(command, element, callback)
		local stanza = verse.iq({ to = self.peer, type = "set" })
			:tag("jingle", {
				xmlns = xmlns_jingle,
				sid = self.sid,
				action = command,
				initiator = self.role == "initiator" and self.stream.jid or nil,
				responder = self.role == "responder" and self.jid or nil,
			}):add_child(element);
		if not callback then
			self.stream:send(stanza);
		else
			self.stream:send_iq(stanza, callback);
		end
	end
		
	function jingle_mt:accept(options)
		local accept_stanza = verse.iq({ to = self.peer, type = "set" })
			:tag("jingle", {
				xmlns = xmlns_jingle,
				sid = self.sid,
				action = "session-accept",
				responder = stream.jid,
			})
				:tag("content", { creator = self.creator, name = self.name });
		
		local content_accept_tag = self.content:generate_accept(self.content_tag:child_with_name("description"), options);
		accept_stanza:add_child(content_accept_tag);
		
		local transport_accept_tag = self.transport:generate_accept(self.content_tag:child_with_name("transport"), options);
		accept_stanza:add_child(transport_accept_tag);
		
		local jingle = self;
		stream:send_iq(accept_stanza, function (result)
			if result.attr.type == "error" then
				local type, condition, text = result:get_error();
				stream:error("session-accept rejected: %s", condition); -- FIXME: Notify
				return false;
			end
			jingle.transport:connect(function (conn)
				stream:warn("CONNECTED (receiver)!!!");
				jingle.state = "active";
				jingle:event("connected", conn);
			end);
		end);
	end
	

	stream:hook("iq/"..xmlns_jingle, handle_incoming_jingle);
	return true;
end

function jingle_mt:offer(name, content)
	local session_initiate = verse.iq({ to = self.peer, type = "set" })
		:tag("jingle", { xmlns = xmlns_jingle, action = "session-initiate",
			initiator = self.stream.jid, sid = self.sid });
	
	-- Content tag
	session_initiate:tag("content", { creator = self.role, name = name });
	
	-- Need description element from someone who can turn 'content' into XML
	local description = self.stream:event("jingle/describe/"..name, content);
	
	if not description then
		return false, "Unknown content type";
	end
	
	session_initiate:add_child(description);
	
	-- FIXME: Sort transports by 1) recipient caps 2) priority (SOCKS vs IBB, etc.)
	-- Fixed to s5b in the meantime
	local transport = self.stream:event("jingle/transport/".."urn:xmpp:jingle:transports:s5b:1", self);
	self.transport = transport;
	
	session_initiate:add_child(transport:generate_initiate());
	
	self.stream:debug("Hooking %s", "jingle/"..self.sid);
	self.stream:hook("jingle/"..self.sid, function (stanza)
		if stanza.attr.from ~= self.peer then
			return false;
		end
		local jingle_tag = stanza:get_child("jingle", xmlns_jingle);
		return self:handle_command(jingle_tag)
	end);
	
	self.stream:send_iq(session_initiate, function (result)
		if result.type == "error" then
			self.state = "terminated";
			local type, condition, text = result:get_error();
			return self:event("error", { type = type, condition = condition, text = text });
		end
	end);
	self.state = "pending";
end

function jingle_mt:terminate(reason)
	local reason_tag = verse.stanza("reason"):tag(reason or "success");
	self:send_command("session-terminate", reason_tag, function (result)
		self.state = "terminated";
		self.transport:disconnect();
		self:destroy();
	end);
end

function jingle_mt:destroy()
	self:event("terminated");
	self.stream:unhook("jingle/"..self.sid, self.handle_command);
end

function jingle_mt:handle_accepted(jingle_tag)
	local transport_tag = jingle_tag:child_with_name("transport");
	self.transport:handle_accepted(transport_tag);
	self.transport:connect(function (conn)
		print("CONNECTED (initiator)!")
		-- Connected, send file
		self.state = "active";
		self:event("connected", conn);
	end);
end

function jingle_mt:set_source(source, auto_close)
	local function pump()
		local chunk, err = source();
		if chunk and chunk ~= "" then
			self.transport.conn:send(chunk);
		elseif chunk == "" then
			return pump(); -- We need some data!
		elseif chunk == nil then
			if auto_close then
				self:terminate();
			end
			self.transport.conn:unhook("drained", pump);
			source = nil;
		end
	end
	self.transport.conn:hook("drained", pump);
	pump();
end

function jingle_mt:set_sink(sink)
	self.transport.conn:hook("incoming-raw", sink);
	self.transport.conn:hook("disconnected", function (event)
		self.stream:debug("Closing sink...");
		local reason = event.reason;
		if reason == "closed" then reason = nil; end
		sink(nil, reason);
	end);
end
 end)
package.preload['verse.plugins.jingle_ft'] = (function (...)
local ltn12 = require "ltn12";

local dirsep = package.config:sub(1,1);

local xmlns_jingle_ft = "urn:xmpp:jingle:apps:file-transfer:1";
local xmlns_si_file_transfer = "http://jabber.org/protocol/si/profile/file-transfer";

function verse.plugins.jingle_ft(stream)
	stream:hook("ready", function ()
		stream:add_disco_feature(xmlns_jingle_ft);
	end, 10);
	
	local ft_content = { type = "file" };
	
	function ft_content:generate_accept(description, options)
		if options and options.save_file then
			self.jingle:hook("connected", function ()
				local sink = ltn12.sink.file(io.open(options.save_file, "w+"));
				self.jingle:set_sink(sink);
			end);
		end
		
		return description;
	end
	
	local ft_mt = { __index = ft_content };
	stream:hook("jingle/content/"..xmlns_jingle_ft, function (jingle, description_tag)
		local file_tag = description_tag:get_child("offer"):get_child("file", xmlns_si_file_transfer);
		local file = {
			name = file_tag.attr.name;
			size = tonumber(file_tag.attr.size);
		};
		
		return setmetatable({ jingle = jingle, file = file }, ft_mt);
	end);
	
	stream:hook("jingle/describe/file", function (file_info)
		-- Return <description/>
		local date;
		if file_info.timestamp then
			date = os.date("!%Y-%m-%dT%H:%M:%SZ", file_info.timestamp);
		end
		return verse.stanza("description", { xmlns = xmlns_jingle_ft })
			:tag("offer")
				:tag("file", { xmlns = xmlns_si_file_transfer,
					name = file_info.filename, -- Mandatory
					size = file_info.size, -- Mandatory
					date = date,
					hash = file_info.hash,
				})
					:tag("desc"):text(file_info.description or "");
	end);

	function stream:send_file(to, filename)
		local file, err = io.open(filename);
		if not file then return file, err; end
		
		local file_size = file:seek("end", 0);
		file:seek("set", 0);
		
		local source = ltn12.source.file(file);
		
		local jingle = self:jingle(to);
		jingle:offer("file", {
			filename = filename:match("[^"..dirsep.."]+$");
			size = file_size;
		});
		jingle:hook("connected", function ()
			jingle:set_source(source, true);
		end);
		return jingle;
	end
end
 end)
package.preload['verse.plugins.jingle_s5b'] = (function (...)

local xmlns_s5b = "urn:xmpp:jingle:transports:s5b:1";
local sha1 = require "util.sha1".sha1;
local uuid_generate = require "util.uuid".generate;

local function negotiate_socks5(conn, hash)
	local function suppress_connected()
		conn:unhook("connected", suppress_connected);
		return true;
	end
	local function receive_connection_response(data)
		conn:unhook("incoming-raw", receive_connection_response);
		
		if data:sub(1, 2) ~= "\005\000" then
			return conn:event("error", "connection-failure");
		end
		conn:event("connected");
		return true;
	end
	local function receive_auth_response(data)
		conn:unhook("incoming-raw", receive_auth_response);
		if data ~= "\005\000" then -- SOCKSv5; "NO AUTHENTICATION"
			-- Server is not SOCKSv5, or does not allow no auth
			local err = "version-mismatch";
			if data:sub(1,1) == "\005" then
				err = "authentication-failure";
			end
			return conn:event("error", err);
		end
		-- Request SOCKS5 connection
		conn:send(string.char(0x05, 0x01, 0x00, 0x03, #hash)..hash.."\0\0"); --FIXME: Move to "connected"?
		conn:hook("incoming-raw", receive_connection_response, 100);
		return true;
	end
	conn:hook("connected", suppress_connected, 200);
	conn:hook("incoming-raw", receive_auth_response, 100);
	conn:send("\005\001\000"); -- SOCKSv5; 1 mechanism; "NO AUTHENTICATION"
end

local function connect_to_usable_streamhost(callback, streamhosts, auth_token)
	local conn = verse.new(nil, {
		streamhosts = streamhosts,
		current_host = 0;
	});
	--Attempt to connect to the next host
	local function attempt_next_streamhost(event)
		if event then
			return callback(nil, event.reason); 
		end
		-- First connect, or the last connect failed
		if conn.current_host < #conn.streamhosts then
			conn.current_host = conn.current_host + 1;
			conn:debug("Attempting to connect to "..conn.streamhosts[conn.current_host].host..":"..conn.streamhosts[conn.current_host].port.."...");
			local ok, err = conn:connect(
				conn.streamhosts[conn.current_host].host,
				conn.streamhosts[conn.current_host].port
			);
			if not ok then
				conn:debug("Error connecting to proxy (%s:%s): %s", 
					conn.streamhosts[conn.current_host].host,
					conn.streamhosts[conn.current_host].port,
					err
				);
			else
				conn:debug("Connecting...");
			end
			negotiate_socks5(conn, auth_token);
			return true; -- Halt processing of disconnected event
		end
		-- All streamhosts tried, none successful
		conn:unhook("disconnected", attempt_next_streamhost);
		return callback(nil);
		-- Let disconnected event fall through to user handlers...
	end
	conn:hook("disconnected", attempt_next_streamhost, 100);
	-- When this event fires, we're connected to a streamhost
	conn:hook("connected", function ()
		conn:unhook("disconnected", attempt_next_streamhost);
		callback(conn.streamhosts[conn.current_host], conn);
	end, 100);
	attempt_next_streamhost(); -- Set it in motion
	return conn;
end

function verse.plugins.jingle_s5b(stream)
	stream:hook("ready", function ()
		stream:add_disco_feature(xmlns_s5b);
	end, 10);

	local s5b = {};
	
	function s5b:generate_initiate()
		self.s5b_sid = uuid_generate();
		local transport = verse.stanza("transport", { xmlns = xmlns_s5b,
			mode = "tcp", sid = self.s5b_sid });
		local p = 0;
		for jid, streamhost in pairs(stream.proxy65.available_streamhosts) do
			p = p + 1;
			transport:tag("candidate", { jid = jid, host = streamhost.host,
				port = streamhost.port, cid=jid, priority = p, type = "proxy" }):up();
		end
		stream:debug("Have %d proxies", p)
		return transport;
	end
	
	function s5b:generate_accept(initiate_transport)
		local candidates = {};
		self.s5b_peer_candidates = candidates;
		self.s5b_mode = initiate_transport.attr.mode or "tcp";
		self.s5b_sid = initiate_transport.attr.sid or self.jingle.sid;
		
		-- Import the list of candidates the initiator offered us
		for candidate in initiate_transport:childtags() do
			--if candidate.attr.jid == "asterix4@jabber.lagaule.org/Gajim"
			--and candidate.attr.host == "82.246.25.239" then
				candidates[candidate.attr.cid] = {
					type = candidate.attr.type;
					jid = candidate.attr.jid;
					host = candidate.attr.host;
					port = tonumber(candidate.attr.port) or 0;
					priority = tonumber(candidate.attr.priority) or 0;
					cid = candidate.attr.cid;
				};
			--end
		end
		
		-- Import our own candidates
		-- TODO ^
		local transport = verse.stanza("transport", { xmlns = xmlns_s5b });
		return transport;
	end
	
	function s5b:connect(callback)
		stream:warn("Connecting!");
		
		local streamhost_array = {};
		for cid, streamhost in pairs(self.s5b_peer_candidates or {}) do
			streamhost_array[#streamhost_array+1] = streamhost;
		end
		
		if #streamhost_array > 0 then
			self.connecting_peer_candidates = true;
			local function onconnect(streamhost, conn)
				self.jingle:send_command("transport-info", verse.stanza("content", { creator = self.creator, name = self.name })
					:tag("transport", { xmlns = xmlns_s5b, sid = self.s5b_sid })
						:tag("candidate-used", { cid = streamhost.cid }));
				self.onconnect_callback = callback;
				self.conn = conn;
			end
			local auth_token = sha1(self.s5b_sid..self.peer..stream.jid, true);
			connect_to_usable_streamhost(onconnect, streamhost_array, auth_token);
		else
			stream:warn("Actually, I'm going to wait for my peer to tell me its streamhost...");
			self.onconnect_callback = callback;
		end
	end
	
	function s5b:info_received(jingle_tag)
		stream:warn("Info received");
		local content_tag = jingle_tag:child_with_name("content");
		local transport_tag = content_tag:child_with_name("transport");
		if transport_tag:get_child("candidate-used") and not self.connecting_peer_candidates then
			local candidate_used = transport_tag:child_with_name("candidate-used");
			if candidate_used then
				-- Connect straight away to candidate used, we weren't trying any anyway
				local function onconnect(streamhost, conn)
					if self.jingle.role == "initiator" then -- More correct would be - "is this a candidate we offered?"
						-- Activate the stream
						self.jingle.stream:send_iq(verse.iq({ to = streamhost.jid, type = "set" })
							:tag("query", { xmlns = xmlns_bytestreams, sid = self.s5b_sid })
								:tag("activate"):text(self.jingle.peer), function (result)
							
							if result.attr.type == "result" then
								self.jingle:send_command("transport-info", verse.stanza("content", content_tag.attr)
									:tag("transport", { xmlns = xmlns_s5b, sid = self.s5b_sid })
										:tag("activated", { cid = candidate_used.attr.cid }));
								self.conn = conn;
								self.onconnect_callback(conn);
							else
								self.jingle.stream:error("Failed to activate bytestream");
							end
						end);
					end
				end
				
				-- FIXME: Another assumption that cid==jid, and that it was our candidate
				self.jingle.stream:debug("CID: %s", self.jingle.stream.proxy65.available_streamhosts[candidate_used.attr.cid]);
				local streamhost_array = {
					self.jingle.stream.proxy65.available_streamhosts[candidate_used.attr.cid];
				};

				local auth_token = sha1(self.s5b_sid..stream.jid..self.peer, true);
				connect_to_usable_streamhost(onconnect, streamhost_array, auth_token);
			end
		elseif transport_tag:get_child("activated") then
			self.onconnect_callback(self.conn);
		end
	end
	
	function s5b:disconnect()
		if self.conn then
			self.conn:close();
		end
	end
	
	function s5b:handle_accepted(jingle_tag)
	end

	local s5b_mt = { __index = s5b };
	stream:hook("jingle/transport/"..xmlns_s5b, function (jingle)
		return setmetatable({
			role = jingle.role,
			peer = jingle.peer,
			stream = jingle.stream,
			jingle = jingle,
		}, s5b_mt);
	end);
end
 end)
package.preload['verse.plugins.presence'] = (function (...)
function verse.plugins.presence(stream)
	stream.last_presence = nil;

	stream:hook("presence-out", function (presence)
		if not presence.attr.to then
			stream.last_presence = presence; -- Cache non-directed presence
		end
	end, 1);

	function stream:resend_presence()
		if last_presence then
			stream:send(last_presence);
		end
	end

	function stream:set_status(opts)
		local p = verse.presence();
		if type(opts) == "table" then
			if opts.show then
				p:tag("show"):text(opts.show):up();
			end
			if opts.prio then
				p:tag("priority"):text(tostring(opts.prio)):up();
			end
			if opts.msg then
				p:tag("status"):text(opts.msg):up();
			end
		end
		-- TODO maybe use opts as prio if it's a int,
		-- or as show or status if it's a string?

		stream:send(p);
	end
end
 end)
package.preload['verse.plugins.disco'] = (function (...)
-- Verse XMPP Library
-- Copyright (C) 2010 Hubert Chathi <hubert@uhoreg.ca>
-- Copyright (C) 2010 Matthew Wild <mwild1@gmail.com>
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local b64 = require("mime").b64
local sha1 = require("util.sha1").sha1

local xmlns_caps = "http://jabber.org/protocol/caps";
local xmlns_disco = "http://jabber.org/protocol/disco";
local xmlns_disco_info = xmlns_disco.."#info";
local xmlns_disco_items = xmlns_disco.."#items";

function verse.plugins.disco(stream)
	stream:add_plugin("presence");
	stream.disco = { cache = {}, info = {} }
	stream.disco.info.identities = {
		{category = 'client', type='pc', name='Verse'},
	}
	stream.disco.info.features = {
		{var = xmlns_caps},
		{var = xmlns_disco_info},
		{var = xmlns_disco_items},
	}
	stream.disco.items = {}
	stream.disco.nodes = {}

	stream.caps = {}
	stream.caps.node = 'http://code.matthewwild.co.uk/verse/'

	local function cmp_identity(item1, item2)
		if item1.category < item2.category then
			return true;
		elseif item2.category < item1.category then
			return false;
		end
		if item1.type < item2.type then
			return true;
		elseif item2.type < item1.type then
			return false;
		end
		if (not item1['xml:lang'] and item2['xml:lang']) or
			 (item2['xml:lang'] and item1['xml:lang'] < item2['xml:lang']) then
			return true
		end
		return false
	end

	local function cmp_feature(item1, item2)
		return item1.var < item2.var
	end

	local function calculate_hash()
		table.sort(stream.disco.info.identities, cmp_identity)
		table.sort(stream.disco.info.features, cmp_feature)
		local S = ''
		for key,identity in pairs(stream.disco.info.identities) do
			S = S .. string.format(
				'%s/%s/%s/%s', identity.category, identity.type,
				identity['xml:lang'] or '', identity.name or ''
			) .. '<'
		end
		for key,feature in pairs(stream.disco.info.features) do
			S = S .. feature.var .. '<'
		end
		-- FIXME: make sure S is utf8-encoded
		--stream:debug("Computed hash string: "..S);
		--stream:debug("Computed hash string (sha1): "..sha1(S, true));
		--stream:debug("Computed hash string (sha1+b64): "..b64(sha1(S)));
		return (b64(sha1(S)))
	end

	setmetatable(stream.caps, {
		__call = function (...) -- vararg: allow calling as function or member
			-- retrieve the c stanza to insert into the
			-- presence stanza
			local hash = calculate_hash()
			return verse.stanza('c', {
				xmlns = xmlns_caps,
				hash = 'sha-1',
				node = stream.caps.node,
				ver = hash
			})
		end
	})
	
	function stream:add_disco_feature(feature)
		table.insert(self.disco.info.features, {var=feature});
		stream:resend_presence();
	end
	
	function stream:remove_disco_feature(feature)
		for idx, disco_feature in ipairs(self.disco.info.features) do
			if disco_feature.var == feature then
				table.remove(self.disco.info.features, idx);
				stream:resend_presence();
				return true;
			end
		end
	end

	function stream:add_disco_item(item, node)
		local disco_items = self.disco.items;
		if node then
			disco_items = self.disco.nodes[node];
			if not disco_items then
				disco_items = { features = {}, items = {} };
				self.disco.nodes[node] = disco_items;
				disco_items = disco_items.items;
			else
				disco_items = disco_items.items;
			end
		end
		table.insert(disco_items, item);
	end

	function stream:jid_has_identity(jid, category, type)
		local cached_disco = self.disco.cache[jid];
		if not cached_disco then
			return nil, "no-cache";
		end
		local identities = self.disco.cache[jid].identities;
		if type then
			return identities[category.."/"..type] or false;
		end
		-- Check whether we have any identities with this category instead
		for identity in pairs(identities) do
			if identity:match("^(.*)/") == category then
				return true;
			end
		end
	end

	function stream:jid_supports(jid, feature)
		local cached_disco = self.disco.cache[jid];
		if not cached_disco or not cached_disco.features then
			return nil, "no-cache";
		end
		return cached_disco.features[feature] or false;
	end
	
	function stream:get_local_services(category, type)
		local host_disco = self.disco.cache[self.host];
		if not(host_disco) or not(host_disco.items) then
			return nil, "no-cache";
		end
		
		local results = {};
		for _, service in ipairs(host_disco.items) do
			if self:jid_has_identity(service.jid, category, type) then
				table.insert(results, service.jid);
			end
		end
		return results;
	end
	
	function stream:disco_local_services(callback)
		self:disco_items(self.host, nil, function (items)
			if not items then
				return callback({});
			end
			local n_items = 0;
			local function item_callback()
				n_items = n_items - 1;
				if n_items == 0 then
					return callback(items);
				end
			end
			
			for _, item in ipairs(items) do
				if item.jid then
					n_items = n_items + 1;
					self:disco_info(item.jid, nil, item_callback);
				end
			end
			if n_items == 0 then
				return callback(items);
			end
		end);
	end
	
	function stream:disco_info(jid, node, callback)
		local disco_request = verse.iq({ to = jid, type = "get" })
			:tag("query", { xmlns = xmlns_disco_info, node = node });
		self:send_iq(disco_request, function (result)
			if result.attr.type == "error" then
				return callback(nil, result:get_error());
			end
			
			local identities, features = {}, {};
			
			for tag in result:get_child("query", xmlns_disco_info):childtags() do
				if tag.name == "identity" then
					identities[tag.attr.category.."/"..tag.attr.type] = tag.attr.name or true;
				elseif tag.name == "feature" then
					features[tag.attr.var] = true;
				end
			end
			

			if not self.disco.cache[jid] then
				self.disco.cache[jid] = { nodes = {} };
			end

			if node then
				if not self.disco.cache[jid].nodes[node] then
					self.disco.cache[jid].nodes[node] = { nodes = {} };
				end
				self.disco.cache[jid].nodes[node].identities = identities;
				self.disco.cache[jid].nodes[node].features = features;
			else
				self.disco.cache[jid].identities = identities;
				self.disco.cache[jid].features = features;
			end
			return callback(self.disco.cache[jid]);
		end);
	end
	
	function stream:disco_items(jid, node, callback)
		local disco_request = verse.iq({ to = jid, type = "get" })
			:tag("query", { xmlns = xmlns_disco_items, node = node });
		self:send_iq(disco_request, function (result)
			if result.attr.type == "error" then
				return callback(nil, result:get_error());
			end
			local disco_items = { };
			for tag in result:get_child("query", xmlns_disco_items):childtags() do
				if tag.name == "item" then
					table.insert(disco_items, {
						name = tag.attr.name;
						jid = tag.attr.jid;
						node = tag.attr.node;
					});
				end
			end
			
			if not self.disco.cache[jid] then
				self.disco.cache[jid] = { nodes = {} };
			end
			
			if node then
				if not self.disco.cache[jid].nodes[node] then
					self.disco.cache[jid].nodes[node] = { nodes = {} };
				end
				self.disco.cache[jid].nodes[node].items = disco_items;
			else
				self.disco.cache[jid].items = disco_items;
			end
			return callback(disco_items);
		end);
	end
	
	stream:hook("iq/"..xmlns_disco_info, function (stanza)
		if stanza.attr.type == 'get' then
			local query = stanza:child_with_name('query')
			if not query then return; end
			-- figure out what identities/features to send
			local identities
			local features
			if query.attr.node then
				local hash = calculate_hash()
				local node = stream.disco.nodes[query.attr.node]
				if node and node.info then
					identities = node.info.identities or {}
					features = node.info.identities or {}
				elseif query.attr.node == stream.caps.node..'#'..hash then
					-- matches caps hash, so use the main info
					identities = stream.disco.info.identities
					features = stream.disco.info.features
				else
					-- unknown node: give an error
					local response = verse.stanza('iq',{
						to = stanza.attr.from,
						from = stanza.attr.to,
						id = stanza.attr.id,
						type = 'error'
					})
					response:tag('query',{xmlns = xmlns_disco_info}):reset()
					response:tag('error',{type = 'cancel'}):tag(
						'item-not-found',{xmlns = 'urn:ietf:params:xml:ns:xmpp-stanzas'}
					)
					stream:send(response)
					return true
				end
			else
				identities = stream.disco.info.identities
				features = stream.disco.info.features
			end
			-- construct the response
			local result = verse.stanza('query',{
				xmlns = xmlns_disco_info,
				node = query.attr.node
			})
			for key,identity in pairs(identities) do
				result:tag('identity', identity):reset()
			end
			for key,feature in pairs(features) do
				result:tag('feature', feature):reset()
			end
			stream:send(verse.stanza('iq',{
				to = stanza.attr.from,
				from = stanza.attr.to,
				id = stanza.attr.id,
				type = 'result'
			}):add_child(result))
			return true
		end
	end);

	stream:hook("iq/"..xmlns_disco_items, function (stanza)
		if stanza.attr.type == 'get' then
			local query = stanza:child_with_name('query')
			if not query then return; end
			-- figure out what items to send
			local items
			if query.attr.node then
				local node = stream.disco.nodes[query.attr.node]
				if node then
					items = node.items or {}
				else
					-- unknown node: give an error
					local response = verse.stanza('iq',{
						to = stanza.attr.from,
						from = stanza.attr.to,
						id = stanza.attr.id,
						type = 'error'
					})
					response:tag('query',{xmlns = xmlns_disco_items}):reset()
					response:tag('error',{type = 'cancel'}):tag(
						'item-not-found',{xmlns = 'urn:ietf:params:xml:ns:xmpp-stanzas'}
					)
					stream:send(response)
					return true
				end
			else
				items = stream.disco.items
			end
			-- construct the response
			local result = verse.stanza('query',{
				xmlns = xmlns_disco_items,
				node = query.attr.node
			})
			for key,item in pairs(items) do
				result:tag('item', item):reset()
			end
			stream:send(verse.stanza('iq',{
				to = stanza.attr.from,
				from = stanza.attr.to,
				id = stanza.attr.id,
				type = 'result'
			}):add_child(result))
			return true
		end
	end);
	
	local initial_disco_started;
	stream:hook("ready", function ()
		if initial_disco_started then return; end
		initial_disco_started = true;
		stream:disco_local_services(function (services)
			for _, service in ipairs(services) do
				local service_disco_info = stream.disco.cache[service.jid];
				if service_disco_info then
					for identity in pairs(service_disco_info.identities) do
						local category, type = identity:match("^(.*)/(.*)$");
						stream:event("disco/service-discovered/"..category, {
							type = type, jid = service.jid;
						});
					end
				end
			end
			stream:event("ready");
		end);
		return true;
	end, 5);
	
	stream:hook("presence-out", function (presence)
		if not presence:get_child("c", xmlns_caps) then
			presence:reset():add_child(stream:caps()):reset();
		end
	end, 10);
end

-- end of disco.lua
 end)
package.preload['verse.plugins.pep'] = (function (...)

local xmlns_pubsub = "http://jabber.org/protocol/pubsub";
local xmlns_pubsub_event = xmlns_pubsub.."#event";

function verse.plugins.pep(stream)
	stream.pep = {};
	
	stream:hook("message", function (message)
		local event = message:get_child("event", xmlns_pubsub_event);
		if not event then return; end
		local items = event:get_child("items");
		if not items then return; end
		local node = items.attr.node;
		for item in items:childtags() do
			if item.name == "item" and item.attr.xmlns == xmlns_pubsub_event then
				stream:event("pep/"..node, {
					from = message.attr.from,
					item = item.tags[1],
				});
			end
		end
	end);
	
	function stream:hook_pep(node, callback, priority)
		local handlers = stream.events._handlers["pep/"..node];
		if not(handlers) or #handlers == 0 then
			stream:add_disco_feature(node.."+notify");
		end
		stream:hook("pep/"..node, callback, priority);
	end
	
	function stream:unhook_pep(node, callback)
		stream:unhook("pep/"..node, callback);
		local handlers = stream.events._handlers["pep/"..node];
		if not(handlers) or #handlers == 0 then
			stream:remove_disco_feature(node.."+notify");
		end
	end
	
	function stream:publish_pep(item, node)
		local publish = verse.iq({ type = "set" })
			:tag("pubsub", { xmlns = xmlns_pubsub })
				:tag("publish", { node = node or item.attr.xmlns })
					:tag("item")
						:add_child(item);
		return stream:send_iq(publish);
	end
end
 end)
package.preload['verse.plugins.adhoc'] = (function (...)
local adhoc = require "lib.adhoc";

local xmlns_commands = "http://jabber.org/protocol/commands";
local xmlns_data = "jabber:x:data";

local command_mt = {};
command_mt.__index = command_mt;

-- Table of commands we provide
local commands = {};

function verse.plugins.adhoc(stream)
	stream:add_disco_feature(xmlns_commands);

	function stream:query_commands(jid, callback)
		stream:disco_items(jid, xmlns_commands, function (items)
			stream:debug("adhoc list returned")
			local command_list = {};
			for _, item in ipairs(items) do
				command_list[item.node] = item.name;
			end
			stream:debug("adhoc calling callback")
			return callback(command_list);
		end);
	end
	
	function stream:execute_command(jid, command, callback)
		local cmd = setmetatable({
			stream = stream, jid = jid,
			command = command, callback = callback 
		}, command_mt);
		return cmd:execute();
	end
	
	-- ACL checker for commands we provide
	local function has_affiliation(jid, aff)
		if not(aff) or aff == "user" then return true; end
		if type(aff) == "function" then
			return aff(jid);
		end
		-- TODO: Support 'roster', etc.
	end
	
	function stream:add_adhoc_command(name, node, handler, permission)
		commands[node] = adhoc.new(name, node, handler, permission);
		stream:add_disco_item({ jid = stream.jid, node = node, name = name }, xmlns_commands);
		return commands[node];
	end
	
	local function handle_command(stanza)
		local command_tag = stanza.tags[1];
		local node = command_tag.attr.node;
		
		local handler = commands[node];
		if not handler then return; end
		
		if not has_affiliation(stanza.attr.from, handler.permission) then
			stream:send(verse.error_reply(stanza, "auth", "forbidden", "You don't have permission to execute this command"):up()
			:add_child(handler:cmdtag("canceled")
				:tag("note", {type="error"}):text("You don't have permission to execute this command")));
			return true
		end
		
		-- User has permission now execute the command
		return adhoc.handle_cmd(handler, { send = function (d) return stream:send(d) end }, stanza);
	end
	
	stream:hook("iq/"..xmlns_commands, function (stanza)
		local type = stanza.attr.type;
		local name = stanza.tags[1].name;
		if type == "set" and name == "command" then
			return handle_command(stanza);
		end
	end);
end

function command_mt:_process_response(result)
	if result.type == "error" then
		self.status = "canceled";
		self.callback(self, {});
	end
	local command = result:get_child("command", xmlns_commands);
	self.status = command.attr.status;
	self.sessionid = command.attr.sessionid;
	self.form = command:get_child("x", xmlns_data);
	self.callback(self);
end

-- Initial execution of a command
function command_mt:execute()
	local iq = verse.iq({ to = self.jid, type = "set" })
		:tag("command", { xmlns = xmlns_commands, node = self.command });
	self.stream:send_iq(iq, function (result)
		self:_process_response(result);
	end);
end

function command_mt:next(form)
	local iq = verse.iq({ to = self.jid, type = "set" })
		:tag("command", {
			xmlns = xmlns_commands,
			node = self.command,
			sessionid = self.sessionid
		});
	
	if form then iq:add_child(form); end
	
	self.stream:send_iq(iq, function (result)
		self:_process_response(result);
	end);
end
 end)
package.preload['verse.plugins.private'] = (function (...)
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

 end)
package.preload['verse.plugins.groupchat'] = (function (...)
local events = require "events";

local room_mt = {};
room_mt.__index = room_mt;

local xmlns_delay = "urn:xmpp:delay";
local xmlns_muc = "http://jabber.org/protocol/muc";

function verse.plugins.groupchat(stream)
	stream:add_plugin("presence")
	stream.rooms = {};
	
	stream:hook("stanza", function (stanza)
		local room_jid = jid.bare(stanza.attr.from);
		if not room_jid then return end
		local room = stream.rooms[room_jid]
		if not room and stanza.attr.to and room_jid then
			room = stream.rooms[stanza.attr.to.." "..room_jid]
		end
		if room and room.opts.source and stanza.attr.to ~= room.opts.source then return end
		if room then
			local nick = select(3, jid.split(stanza.attr.from));
			local body = stanza:get_child("body");
			local delay = stanza:get_child("delay", xmlns_delay);
			local event = {
				room_jid = room_jid;
				room = room;
				sender = room.occupants[nick];
				nick = nick;
				body = (body and body:get_text()) or nil;
				stanza = stanza;
				delay = (delay and delay.attr.stamp);
			};
			local ret = room:event(stanza.name, event);
			return ret or (stanza.name == "message") or nil;
		end
	end, 500);
	
	function stream:join_room(jid, nick, opts)
		if not nick then
			return false, "no nickname supplied"
		end
		opts = opts or {};
		local room = setmetatable({
			stream = stream, jid = jid, nick = nick,
			subject = nil,
			occupants = {},
			opts = opts,
			events = events.new()
		}, room_mt);
		if opts.source then
			self.rooms[opts.source.." "..jid] = room;
		else
			self.rooms[jid] = room;
		end
		local occupants = room.occupants;
		room:hook("presence", function (presence)
			local nick = presence.nick or nick;
			if not occupants[nick] and presence.stanza.attr.type ~= "unavailable" then
				occupants[nick] = {
					nick = nick;
					jid = presence.stanza.attr.from;
					presence = presence.stanza;
				};
				local x = presence.stanza:get_child("x", xmlns_muc .. "#user");
				if x then
					local x_item = x:get_child("item");
					if x_item and x_item.attr then
						occupants[nick].real_jid    = x_item.attr.jid;
						occupants[nick].affiliation = x_item.attr.affiliation;
						occupants[nick].role        = x_item.attr.role;
					end
					--TODO Check for status 100?
				end
				if nick == room.nick then
					room.stream:event("groupchat/joined", room);
				else
					room:event("occupant-joined", occupants[nick]);
				end
			elseif occupants[nick] and presence.stanza.attr.type == "unavailable" then
				if nick == room.nick then
					room.stream:event("groupchat/left", room);
					if room.opts.source then
						self.rooms[room.opts.source.." "..jid] = nil;
					else
						self.rooms[jid] = nil;
					end
				else
					occupants[nick].presence = presence.stanza;
					room:event("occupant-left", occupants[nick]);
					occupants[nick] = nil;
				end
			end
		end);
		room:hook("message", function(msg)
			local subject = msg.stanza:get_child("subject");
			subject = subject and subject:get_text();
			if subject then
				room.subject = #subject > 0 and subject or nil;
			end
		end, 2000);
		local join_st = verse.presence():tag("x",{xmlns = xmlns_muc}):reset();
		self:event("pre-groupchat/joining", join_st);
		room:send(join_st)
		self:event("groupchat/joining", room);
		return room;
	end

	stream:hook("presence-out", function(presence)
		if not presence.attr.to then
			for _, room in pairs(stream.rooms) do
				room:send(presence);
			end
			presence.attr.to = nil;
		end
	end);
end

function room_mt:send(stanza)
	if stanza.name == "message" and not stanza.attr.type then
		stanza.attr.type = "groupchat";
	end
	if stanza.name == "presence" then
		stanza.attr.to = self.jid .."/"..self.nick;
	end
	if stanza.attr.type == "groupchat" or not stanza.attr.to then
		stanza.attr.to = self.jid;
	end
	if self.opts.source then
		stanza.attr.from = self.opts.source
	end
	self.stream:send(stanza);
end

function room_mt:send_message(text)
	self:send(verse.message():tag("body"):text(text));
end

function room_mt:set_subject(text)
	self:send(verse.message():tag("subject"):text(text));
end

function room_mt:leave(message)
	self.stream:event("groupchat/leaving", self);
	self:send(verse.presence({type="unavailable"}));
end

function room_mt:admin_set(nick, what, value, reason)
	self:send(verse.iq({type="set"})
		:query(xmlns_muc .. "#admin")
			:tag("item", {nick = nick, [what] = value})
				:tag("reason"):text(reason or ""));
end

function room_mt:set_role(nick, role, reason)
	self:admin_set(nick, "role", role, reason);
end

function room_mt:set_affiliation(nick, affiliation, reason)
	self:admin_set(nick, "affiliation", affiliation, reason);
end

function room_mt:kick(nick, reason)
	self:set_role(nick, "none", reason);
end

function room_mt:ban(nick, reason)
	self:set_affiliation(nick, "outcast", reason);
end

function room_mt:event(name, arg)
	self.stream:debug("Firing room event: %s", name);
	return self.events.fire_event(name, arg);
end

function room_mt:hook(name, callback, priority)
	return self.events.add_handler(name, callback, priority);
end
 end)
package.preload['verse.plugins.uptime'] = (function (...)
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
 end)
package.preload['verse.plugins.smacks'] = (function (...)
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
 end)
package.preload['verse.plugins.keepalive'] = (function (...)
function verse.plugins.keepalive(stream)
	stream.keepalive_timeout = stream.keepalive_timeout or 300;
	verse.add_task(stream.keepalive_timeout, function ()
		stream.conn:write(" ");
		return stream.keepalive_timeout;
	end);
end
 end)
package.preload['verse.plugins.roster'] = (function (...)
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
 end)
package.preload['net.httpclient_listener'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local log = require "util.logger".init("httpclient_listener");
local t_concat, t_insert = table.concat, table.insert;

local connlisteners_register = require "net.connlisteners".register;

local requests = {}; -- Open requests
local buffers = {}; -- Buffers of partial lines

local httpclient = { default_port = 80, default_mode = "*a" };

function httpclient.onconnect(conn)
	local req = requests[conn];
	-- Send the request
	local request_line = { req.method or "GET", " ", req.path, " HTTP/1.1\r\n" };
	if req.query then
		t_insert(request_line, 4, "?"..req.query);
	end
	
	conn:write(t_concat(request_line));
	local t = { [2] = ": ", [4] = "\r\n" };
	for k, v in pairs(req.headers) do
		t[1], t[3] = k, v;
		conn:write(t_concat(t));
	end
	conn:write("\r\n");
	
	if req.body then
		conn:write(req.body);
	end
end

function httpclient.onincoming(conn, data)
	local request = requests[conn];

	if not request then
		log("warn", "Received response from connection %s with no request attached!", tostring(conn));
		return;
	end

	if data and request.reader then
		request:reader(data);
	end
end

function httpclient.ondisconnect(conn, err)
	local request = requests[conn];
	if request and request.conn then
		request:reader(nil);
	end
	requests[conn] = nil;
end

function httpclient.register_request(conn, req)
	log("debug", "Attaching request %s to connection %s", tostring(req.id or req), tostring(conn));
	requests[conn] = req;
end

connlisteners_register("httpclient", httpclient);
 end)
package.preload['net.connlisteners'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--



local listeners_dir = (CFG_SOURCEDIR or ".").."/net/";
local server = require "net.server";
local log = require "util.logger".init("connlisteners");
local tostring = tostring;
local type = type
local ipairs = ipairs

local dofile, xpcall, error =
      dofile, xpcall, error

local debug_traceback = debug.traceback;

module "connlisteners"

local listeners = {};

function register(name, listener)
	if listeners[name] and listeners[name] ~= listener then
		log("debug", "Listener %s is already registered, not registering any more", name);
		return false;
	end
	listeners[name] = listener;
	log("debug", "Registered connection listener %s", name);
	return true;
end

function deregister(name)
	listeners[name] = nil;
end

function get(name)
	local h = listeners[name];
	if not h then
		local ok, ret = xpcall(function() dofile(listeners_dir..name:gsub("[^%w%-]", "_").."_listener.lua") end, debug_traceback);
		if not ok then
			log("error", "Error while loading listener '%s': %s", tostring(name), tostring(ret));
			return nil, ret;
		end
		h = listeners[name];
	end
	return h;
end

function start(name, udata)
	local h, err = get(name);
	if not h then
		error("No such connection module: "..name.. (err and (" ("..err..")") or ""), 0);
	end
	
	local interfaces = (udata and udata.interface) or h.default_interface or "*";
	if type(interfaces) == "string" then interfaces = {interfaces}; end
	local port = (udata and udata.port) or h.default_port or error("Can't start listener "..name.." because no port was specified, and it has no default port", 0);
	local mode = (udata and udata.mode) or h.default_mode or 1;
	local ssl = (udata and udata.ssl) or nil;
	local autossl = udata and udata.type == "ssl";
	
	if autossl and not ssl then
		return nil, "no ssl context";
	end

	ok, err = true, {};
	for _, interface in ipairs(interfaces) do
		local handler
		handler, err[interface] = server.addserver(interface, port, h, mode, autossl and ssl or nil);
		ok = ok and handler;
	end

	return ok, err;
end

return _M;
 end)
package.preload['util.httpstream'] = (function (...)

local coroutine = coroutine;
local tonumber = tonumber;

local deadroutine = coroutine.create(function() end);
coroutine.resume(deadroutine);

module("httpstream")

local function parser(success_cb, parser_type, options_cb)
	local data = coroutine.yield();
	local function readline()
		local pos = data:find("\r\n", nil, true);
		while not pos do
			data = data..coroutine.yield();
			pos = data:find("\r\n", nil, true);
		end
		local r = data:sub(1, pos-1);
		data = data:sub(pos+2);
		return r;
	end
	local function readlength(n)
		while #data < n do
			data = data..coroutine.yield();
		end
		local r = data:sub(1, n);
		data = data:sub(n + 1);
		return r;
	end
	local function readheaders()
		local headers = {}; -- read headers
		while true do
			local line = readline();
			if line == "" then break; end -- headers done
			local key, val = line:match("^([^%s:]+): *(.*)$");
			if not key then coroutine.yield("invalid-header-line"); end -- TODO handle multi-line and invalid headers
			key = key:lower();
			headers[key] = headers[key] and headers[key]..","..val or val;
		end
		return headers;
	end
	
	if not parser_type or parser_type == "server" then
		while true do
			-- read status line
			local status_line = readline();
			local method, path, httpversion = status_line:match("^(%S+)%s+(%S+)%s+HTTP/(%S+)$");
			if not method then coroutine.yield("invalid-status-line"); end
			path = path:gsub("^//+", "/"); -- TODO parse url more
			local headers = readheaders();
			
			-- read body
			local len = tonumber(headers["content-length"]);
			len = len or 0; -- TODO check for invalid len
			local body = readlength(len);
			
			success_cb({
				method = method;
				path = path;
				httpversion = httpversion;
				headers = headers;
				body = body;
			});
		end
	elseif parser_type == "client" then
		while true do
			-- read status line
			local status_line = readline();
			local httpversion, status_code, reason_phrase = status_line:match("^HTTP/(%S+)%s+(%d%d%d)%s+(.*)$");
			status_code = tonumber(status_code);
			if not status_code then coroutine.yield("invalid-status-line"); end
			local headers = readheaders();
			
			-- read body
			local have_body = not
				 ( (options_cb and options_cb().method == "HEAD")
				or (status_code == 204 or status_code == 304 or status_code == 301)
				or (status_code >= 100 and status_code < 200) );
			
			local body;
			if have_body then
				local len = tonumber(headers["content-length"]);
				if headers["transfer-encoding"] == "chunked" then
					body = "";
					while true do
						local chunk_size = readline():match("^%x+");
						if not chunk_size then coroutine.yield("invalid-chunk-size"); end
						chunk_size = tonumber(chunk_size, 16)
						if chunk_size == 0 then break; end
						body = body..readlength(chunk_size);
						if readline() ~= "" then coroutine.yield("invalid-chunk-ending"); end
					end
					local trailers = readheaders();
				elseif len then -- TODO check for invalid len
					body = readlength(len);
				else -- read to end
					repeat
						local newdata = coroutine.yield();
						data = data..newdata;
					until newdata == "";
					body, data = data, "";
				end
			end
			
			success_cb({
				code = status_code;
				httpversion = httpversion;
				headers = headers;
				body = body;
				-- COMPAT the properties below are deprecated
				responseversion = httpversion;
				responseheaders = headers;
			});
		end
	else coroutine.yield("unknown-parser-type"); end
end

function new(success_cb, error_cb, parser_type, options_cb)
	local co = coroutine.create(parser);
	coroutine.resume(co, success_cb, parser_type, options_cb)
	return {
		feed = function(self, data)
			if not data then
				if parser_type == "client" then coroutine.resume(co, ""); end
				co = deadroutine;
				return error_cb();
			end
			local success, result = coroutine.resume(co, data);
			if result then
				co = deadroutine;
				return error_cb(result);
			end
		end;
	};
end

return _M;
 end)
package.preload['net.http'] = (function (...)
-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local socket = require "socket"
local mime = require "mime"
local url = require "socket.url"
local httpstream_new = require "util.httpstream".new;

local server = require "net.server"

local connlisteners_get = require "net.connlisteners".get;
local listener = connlisteners_get("httpclient") or error("No httpclient listener!");

local t_insert, t_concat = table.insert, table.concat;
local pairs, ipairs = pairs, ipairs;
local tonumber, tostring, xpcall, select, debug_traceback, char, format =
      tonumber, tostring, xpcall, select, debug.traceback, string.char, string.format;

local log = require "util.logger".init("http");

module "http"

function urlencode(s) return s and (s:gsub("%W", function (c) return format("%%%02x", c:byte()); end)); end
function urldecode(s) return s and (s:gsub("%%(%x%x)", function (c) return char(tonumber(c,16)); end)); end

local function _formencodepart(s)
	return s and (s:gsub("%W", function (c)
		if c ~= " " then
			return format("%%%02x", c:byte());
		else
			return "+";
		end
	end));
end

function formencode(form)
	local result = {};
	if form[1] then -- Array of ordered { name, value }
		for _, field in ipairs(form) do
			t_insert(result, _formencodepart(field.name).."=".._formencodepart(field.value));
		end
	else -- Unordered map of name -> value
		for name, value in pairs(form) do
			t_insert(result, _formencodepart(name).."=".._formencodepart(value));
		end
	end
	return t_concat(result, "&");
end

function formdecode(s)
	if not s:match("=") then return urldecode(s); end
	local r = {};
	for k, v in s:gmatch("([^=&]*)=([^&]*)") do
		k, v = k:gsub("%+", "%%20"), v:gsub("%+", "%%20");
		k, v = urldecode(k), urldecode(v);
		t_insert(r, { name = k, value = v });
		r[k] = v;
	end
	return r;
end

local function request_reader(request, data, startpos)
	if not request.parser then
		if not data then return; end
		local function success_cb(r)
			if request.callback then
				for k,v in pairs(r) do request[k] = v; end
				request.callback(r.body, r.code, request);
				request.callback = nil;
			end
			destroy_request(request);
		end
		local function error_cb(r)
			if request.callback then
				request.callback(r or "connection-closed", 0, request);
				request.callback = nil;
			end
			destroy_request(request);
		end
		local function options_cb()
			return request;
		end
		request.parser = httpstream_new(success_cb, error_cb, "client", options_cb);
	end
	request.parser:feed(data);
end

local function handleerr(err) log("error", "Traceback[http]: %s: %s", tostring(err), debug_traceback()); end
function request(u, ex, callback)
	local req = url.parse(u);
	
	if not (req and req.host) then
		callback(nil, 0, req);
		return nil, "invalid-url";
	end
	
	if not req.path then
		req.path = "/";
	end
	
	local method, headers, body;
	
	headers = {
		["Host"] = req.host;
		["User-Agent"] = "Prosody XMPP Server";
	};
	
	if req.userinfo then
		headers["Authorization"] = "Basic "..mime.b64(req.userinfo);
	end

	if ex then
		req.onlystatus = ex.onlystatus;
		body = ex.body;
		if body then
			method = "POST";
			headers["Content-Length"] = tostring(#body);
			headers["Content-Type"] = "application/x-www-form-urlencoded";
		end
		if ex.method then method = ex.method; end
		if ex.headers then
			for k, v in pairs(ex.headers) do
				headers[k] = v;
			end
		end
	end
	
	-- Attach to request object
	req.method, req.headers, req.body = method, headers, body;
	
	local using_https = req.scheme == "https";
	local port = tonumber(req.port) or (using_https and 443 or 80);
	
	-- Connect the socket, and wrap it with net.server
	local conn = socket.tcp();
	conn:settimeout(10);
	local ok, err = conn:connect(req.host, port);
	if not ok and err ~= "timeout" then
		callback(nil, 0, req);
		return nil, err;
	end
	
	req.handler, req.conn = server.wrapclient(conn, req.host, port, listener, "*a", using_https and { mode = "client", protocol = "sslv23" });
	req.write = function (...) return req.handler:write(...); end
	
	req.callback = function (content, code, request) log("debug", "Calling callback, status %s", code or "---"); return select(2, xpcall(function () return callback(content, code, request) end, handleerr)); end
	req.reader = request_reader;
	req.state = "status";

	listener.register_request(req.handler, req);

	return req;
end

function destroy_request(request)
	if request.conn then
		request.conn = nil;
		request.handler:close()
		listener.ondisconnect(request.handler, "closed");
	end
end

_M.urlencode = urlencode;

return _M;
 end)
package.preload['verse.bosh'] = (function (...)

local new_xmpp_stream = require "util.xmppstream".new;
local st = require "util.stanza";
require "net.httpclient_listener"; -- Required for net.http to work
local http = require "net.http";

local stream_mt = setmetatable({}, { __index = verse.stream_mt });
stream_mt.__index = stream_mt;

local xmlns_stream = "http://etherx.jabber.org/streams";
local xmlns_bosh = "http://jabber.org/protocol/httpbind";

local reconnect_timeout = 5;

function verse.new_bosh(logger, url)
	local stream = {
		bosh_conn_pool = {};
		bosh_waiting_requests = {};
		bosh_rid = math.random(1,999999);
		bosh_outgoing_buffer = {};
		bosh_url = url;
		conn = {};
	};
	function stream:reopen()
		self.bosh_need_restart = true;
		self:flush();
	end
	local conn = verse.new(logger, stream);
	return setmetatable(conn, stream_mt);
end

function stream_mt:connect()
	self:_send_session_request();
end

function stream_mt:send(data)
	self:debug("Putting into BOSH send buffer: %s", tostring(data));
	self.bosh_outgoing_buffer[#self.bosh_outgoing_buffer+1] = st.clone(data);
	self:flush(); --TODO: Optimize by doing this on next tick (give a chance for data to buffer)
end

function stream_mt:flush()
	if self.connected
	and #self.bosh_waiting_requests < self.bosh_max_requests
	and (#self.bosh_waiting_requests == 0
		or #self.bosh_outgoing_buffer > 0
		or self.bosh_need_restart) then
		self:debug("Flushing...");
		local payload = self:_make_body();
		local buffer = self.bosh_outgoing_buffer;
		for i, stanza in ipairs(buffer) do
			payload:add_child(stanza);
			buffer[i] = nil;
		end
		self:_make_request(payload);
	else
		self:debug("Decided not to flush.");
	end
end

function stream_mt:_make_request(payload)
	local request, err = http.request(self.bosh_url, { body = tostring(payload) }, function (response, code, request)
		if code ~= 0 then
			self.inactive_since = nil;
			return self:_handle_response(response, code, request);
		end
		
		-- Connection issues, we need to retry this request
		local time = os.time();
		if not self.inactive_since then
			self.inactive_since = time; -- So we know when it is time to give up
		elseif time - self.inactive_since > self.bosh_max_inactivity then
			return self:_disconnected();
		else
			self:debug("%d seconds left to reconnect, retrying in %d seconds...", 
				self.bosh_max_inactivity - (time - self.inactive_since), reconnect_timeout);
		end
		
		-- Set up reconnect timer
		timer.add_task(reconnect_timeout, function ()
			self:debug("Retrying request...");
			-- Remove old request
			for i, waiting_request in ipairs(self.bosh_waiting_requests) do
				if waiting_request == request then
					table.remove(self.bosh_waiting_requests, i);
					break;
				end
			end
			self:_make_request(payload);
		end);
	end);
	if request then
		table.insert(self.bosh_waiting_requests, request);
	else
		self:warn("Request failed instantly: %s", err);
	end
end

function stream_mt:_disconnected()
	self.connected = nil;
	self:event("disconnected");
end

function stream_mt:_send_session_request()
	local body = self:_make_body();
	
	-- XEP-0124
	body.attr.hold = "1";
	body.attr.wait = "60";
	body.attr["xml:lang"] = "en";
	body.attr.ver = "1.6";

	-- XEP-0206
	body.attr.from = self.jid;
	body.attr.to = self.host;
	body.attr.secure = 'true';
	
	http.request(self.bosh_url, { body = tostring(body) }, function (response, code)
		if code == 0 then
			-- Failed to connect
			return self:_disconnected();
		end
		-- Handle session creation response
		local payload = self:_parse_response(response)
		if not payload then
			self:warn("Invalid session creation response");
			self:_disconnected();
			return;
		end
		self.bosh_sid = payload.attr.sid; -- Session id
		self.bosh_wait = tonumber(payload.attr.wait); -- How long the server may hold connections for
		self.bosh_hold = tonumber(payload.attr.hold); -- How many connections the server may hold
		self.bosh_max_inactivity = tonumber(payload.attr.inactivity); -- Max amount of time with no connections
		self.bosh_max_requests = tonumber(payload.attr.requests) or self.bosh_hold; -- Max simultaneous requests we can make
		self.connected = true;
		self:event("connected");
		self:_handle_response_payload(payload);
	end);
end

function stream_mt:_handle_response(response, code, request)
	if self.bosh_waiting_requests[1] ~= request then
		self:warn("Server replied to request that wasn't the oldest");
		for i, waiting_request in ipairs(self.bosh_waiting_requests) do
			if waiting_request == request then
				self.bosh_waiting_requests[i] = nil;
				break;
			end
		end
	else
		table.remove(self.bosh_waiting_requests, 1);
	end
	local payload = self:_parse_response(response);
	if payload then
		self:_handle_response_payload(payload);
	end
	self:flush();
end

function stream_mt:_handle_response_payload(payload)
	for stanza in payload:childtags() do
		if stanza.attr.xmlns == xmlns_stream then
			self:event("stream-"..stanza.name, stanza);
		elseif stanza.attr.xmlns then
			self:event("stream/"..stanza.attr.xmlns, stanza);
		else
			self:event("stanza", stanza);
		end
	end
	if payload.attr.type == "terminate" then
		self:_disconnected({reason = payload.attr.condition});
	end
end

local stream_callbacks = {
	stream_ns = "http://jabber.org/protocol/httpbind", stream_tag = "body",
	default_ns = "jabber:client",
	streamopened = function (session, attr) session.notopen = nil; session.payload = verse.stanza("body", attr); return true; end;
	handlestanza = function (session, stanza) session.payload:add_child(stanza); end;
};
function stream_mt:_parse_response(response)
	self:debug("Parsing response: %s", response);
	if response == nil then
		self:debug("%s", debug.traceback());
		self:_disconnected();
		return;
	end
	local session = { notopen = true, log = self.log };
	local stream = new_xmpp_stream(session, stream_callbacks);
	stream:feed(response);
	return session.payload;
end

function stream_mt:_make_body()
	self.bosh_rid = self.bosh_rid + 1;
	local body = verse.stanza("body", {
		xmlns = xmlns_bosh;
		content = "text/xml; charset=utf-8";
		sid = self.bosh_sid;
		rid = self.bosh_rid;
	});
	if self.bosh_need_restart then
		self.bosh_need_restart = nil;
		body.attr.restart = 'true';
	end
	return body;
end
 end)
package.preload['verse.client'] = (function (...)
local verse = require "verse";
local stream = verse.stream_mt;

local jid_split = require "util.jid".split;
local adns = require "net.adns";
local lxp = require "lxp";
local st = require "util.stanza";

-- Shortcuts to save having to load util.stanza
verse.message, verse.presence, verse.iq, verse.stanza, verse.reply, verse.error_reply =
	st.message, st.presence, st.iq, st.stanza, st.reply, st.error_reply;

local new_xmpp_stream = require "util.xmppstream".new;

local xmlns_stream = "http://etherx.jabber.org/streams";

local function compare_srv_priorities(a,b)
	return a.priority < b.priority or (a.priority == b.priority and a.weight > b.weight);
end

local stream_callbacks = {
	stream_ns = xmlns_stream,
	stream_tag = "stream",
	 default_ns = "jabber:client" };
	
function stream_callbacks.streamopened(stream, attr)
	stream.stream_id = attr.id;
	if not stream:event("opened", attr) then
		stream.notopen = nil;
	end
	return true;
end

function stream_callbacks.streamclosed(stream)
	return stream:event("closed");
end

function stream_callbacks.handlestanza(stream, stanza)
	if stanza.attr.xmlns == xmlns_stream then
		return stream:event("stream-"..stanza.name, stanza);
	elseif stanza.attr.xmlns then
		return stream:event("stream/"..stanza.attr.xmlns, stanza);
	end

	return stream:event("stanza", stanza);
end

function stream:reset()
	if self.stream then
		self.stream:reset();
	else
		self.stream = new_xmpp_stream(self, stream_callbacks);
	end
	self.notopen = true;
	return true;
end

function stream:connect_client(jid, pass)
	self.jid, self.password = jid, pass;
	self.username, self.host, self.resource = jid_split(jid);
	
	-- Required XMPP features
	self:add_plugin("tls");
	self:add_plugin("sasl");
	self:add_plugin("bind");
	self:add_plugin("session");
	
	function self.data(conn, data)
		local ok, err = self.stream:feed(data);
		if ok then return; end
		self:debug("debug", "Received invalid XML (%s) %d bytes: %s", tostring(err), #data, data:sub(1, 300):gsub("[\r\n]+", " "));
		self:close("xml-not-well-formed");
	end
	
	self:hook("connected", function () self:reopen(); end);
	self:hook("incoming-raw", function (data) return self.data(self.conn, data); end);
	
	self.curr_id = 0;
	
	self.tracked_iqs = {};
	self:hook("stanza", function (stanza)
		local id, type = stanza.attr.id, stanza.attr.type;
		if id and stanza.name == "iq" and (type == "result" or type == "error") and self.tracked_iqs[id] then
			self.tracked_iqs[id](stanza);
			self.tracked_iqs[id] = nil;
			return true;
		end
	end);
	
	self:hook("stanza", function (stanza)
		if stanza.attr.xmlns == nil or stanza.attr.xmlns == "jabber:client" then
			if stanza.name == "iq" and (stanza.attr.type == "get" or stanza.attr.type == "set") then
				local xmlns = stanza.tags[1] and stanza.tags[1].attr.xmlns;
				if xmlns then
					ret = self:event("iq/"..xmlns, stanza);
					if not ret then
						ret = self:event("iq", stanza);
					end
				end
				if ret == nil then
					self:send(verse.error_reply(stanza, "cancel", "service-unavailable"));
					return true;
				end
			else
				ret = self:event(stanza.name, stanza);
			end
		end
		return ret;
	end, -1);

	self:hook("outgoing", function (data)
		if data.name then
			self:event("stanza-out", data);
		end
	end);
	
	self:hook("stanza-out", function (stanza)
		if not stanza.attr.xmlns then
			self:event(stanza.name.."-out", stanza);
		end
	end);
	
	local function stream_ready()
		self:event("ready");
	end
	self:hook("session-success", stream_ready, -1)
	self:hook("bind-success", stream_ready, -1);

	local _base_close = self.close;
	function self:close(reason)
		if not self.notopen then
			self:send("</stream:stream>");
		end
		return _base_close(self);
	end
	
	local function start_connect()
		-- Initialise connection
		self:connect(self.connect_host or self.host, self.connect_port or 5222);
	end
	
	if not (self.connect_host or self.connect_port) then
		-- Look up SRV records
		adns.lookup(function (answer)
			if answer then
				local srv_hosts = {};
				self.srv_hosts = srv_hosts;
				for _, record in ipairs(answer) do
					table.insert(srv_hosts, record.srv);
				end
				table.sort(srv_hosts, compare_srv_priorities);
				
				local srv_choice = srv_hosts[1];
				self.srv_choice = 1;
				if srv_choice then
					self.connect_host, self.connect_port = srv_choice.target, srv_choice.port;
					self:debug("Best record found, will connect to %s:%d", self.connect_host or self.host, self.connect_port or 5222);
				end
				
				self:hook("disconnected", function ()
					if self.srv_hosts and self.srv_choice < #self.srv_hosts then
						self.srv_choice = self.srv_choice + 1;
						local srv_choice = srv_hosts[self.srv_choice];
						self.connect_host, self.connect_port = srv_choice.target, srv_choice.port;
						start_connect();
						return true;
					end
				end, 1000);
				
				self:hook("connected", function ()
					self.srv_hosts = nil;
				end, 1000);
			end
			start_connect();
		end, "_xmpp-client._tcp."..(self.host)..".", "SRV");
	else
		start_connect();
	end
end

function stream:reopen()
	self:reset();
	self:send(st.stanza("stream:stream", { to = self.host, ["xmlns:stream"]='http://etherx.jabber.org/streams',
		xmlns = "jabber:client", version = "1.0" }):top_tag());
end

function stream:send_iq(iq, callback)
	local id = self:new_id();
	self.tracked_iqs[id] = callback;
	iq.attr.id = id;
	self:send(iq);
end

function stream:new_id()
	self.curr_id = self.curr_id + 1;
	return tostring(self.curr_id);
end
 end)
package.preload['verse.component'] = (function (...)
local verse = require "verse";
local stream = verse.stream_mt;

local jid_split = require "util.jid".split;
local lxp = require "lxp";
local st = require "util.stanza";
local sha1 = require "util.sha1".sha1;

-- Shortcuts to save having to load util.stanza
verse.message, verse.presence, verse.iq, verse.stanza, verse.reply, verse.error_reply =
	st.message, st.presence, st.iq, st.stanza, st.reply, st.error_reply;

local new_xmpp_stream = require "util.xmppstream".new;

local xmlns_stream = "http://etherx.jabber.org/streams";
local xmlns_component = "jabber:component:accept";

local stream_callbacks = {
	stream_ns = xmlns_stream,
	stream_tag = "stream",
	 default_ns = xmlns_component };
	
function stream_callbacks.streamopened(stream, attr)
	stream.stream_id = attr.id;
	if not stream:event("opened", attr) then
		stream.notopen = nil;
	end
	return true;
end

function stream_callbacks.streamclosed(stream)
	return stream:event("closed");
end

function stream_callbacks.handlestanza(stream, stanza)
	if stanza.attr.xmlns == xmlns_stream then
		return stream:event("stream-"..stanza.name, stanza);
	elseif stanza.attr.xmlns or stanza.name == "handshake" then
		return stream:event("stream/"..(stanza.attr.xmlns or xmlns_component), stanza);
	end

	return stream:event("stanza", stanza);
end

function stream:reset()
	if self.stream then
		self.stream:reset();
	else
		self.stream = new_xmpp_stream(self, stream_callbacks);
	end
	self.notopen = true;
	return true;
end

function stream:connect_component(jid, pass)
	self.jid, self.password = jid, pass;
	self.username, self.host, self.resource = jid_split(jid);
	
	function self.data(conn, data)
		local ok, err = self.stream:feed(data);
		if ok then return; end
		stream:debug("debug", "Received invalid XML (%s) %d bytes: %s", tostring(err), #data, data:sub(1, 300):gsub("[\r\n]+", " "));
		stream:close("xml-not-well-formed");
	end
	
	self:hook("incoming-raw", function (data) return self.data(self.conn, data); end);
	
	self.curr_id = 0;
	
	self.tracked_iqs = {};
	self:hook("stanza", function (stanza)
		local id, type = stanza.attr.id, stanza.attr.type;
		if id and stanza.name == "iq" and (type == "result" or type == "error") and self.tracked_iqs[id] then
			self.tracked_iqs[id](stanza);
			self.tracked_iqs[id] = nil;
			return true;
		end
	end);
	
	self:hook("stanza", function (stanza)
		if stanza.attr.xmlns == nil or stanza.attr.xmlns == "jabber:client" then
			if stanza.name == "iq" and (stanza.attr.type == "get" or stanza.attr.type == "set") then
				local xmlns = stanza.tags[1] and stanza.tags[1].attr.xmlns;
				if xmlns then
					ret = self:event("iq/"..xmlns, stanza);
					if not ret then
						ret = self:event("iq", stanza);
					end
				end
				if ret == nil then
					self:send(verse.error_reply(stanza, "cancel", "service-unavailable"));
					return true;
				end
			else
				ret = self:event(stanza.name, stanza);
			end
		end
		return ret;
	end, -1);

	self:hook("opened", function (attr)
		print(self.jid, self.stream_id, attr.id);
		local token = sha1(self.stream_id..pass, true);

		self:send(st.stanza("handshake", { xmlns = xmlns_component }):text(token));
		self:hook("stream/"..xmlns_component, function (stanza)
			if stanza.name == "handshake" then
				self:event("authentication-success");
			end
		end);
	end);

	local function stream_ready()
		self:event("ready");
	end
	self:hook("authentication-success", stream_ready, -1);

	-- Initialise connection
	self:connect(self.connect_host or self.host, self.connect_port or 5347);
	self:reopen();
end

function stream:reopen()
	self:reset();
	self:send(st.stanza("stream:stream", { to = self.host, ["xmlns:stream"]='http://etherx.jabber.org/streams',
		xmlns = xmlns_component, version = "1.0" }):top_tag());
end

function stream:close(reason)
	if not self.notopen then
		self:send("</stream:stream>");
	end
	local on_disconnect = self.conn.disconnect();
	self.conn:close();
	on_disconnect(conn, reason);
end

function stream:send_iq(iq, callback)
	local id = self:new_id();
	self.tracked_iqs[id] = callback;
	iq.attr.id = id;
	self:send(iq);
end

function stream:new_id()
	self.curr_id = self.curr_id + 1;
	return tostring(self.curr_id);
end
 end)

-- Use LuaRocks if available
pcall(require, "luarocks.require");

-- Load LuaSec if available
pcall(require, "ssl");

local server = require "net.server";
local events = require "util.events";

module("verse", package.seeall);
local verse = _M;
_M.server = server;

local stream = {};
stream.__index = stream;
stream_mt = stream;

verse.plugins = {};

function verse.new(logger, base)
	local t = setmetatable(base or {}, stream);
	t.id = tostring(t):match("%x*$");
	t:set_logger(logger, true);
	t.events = events.new();
	t.plugins = {};
	return t;
end

verse.add_task = require "util.timer".add_task;

verse.logger = logger.init;
verse.log = verse.logger("verse");

function verse.set_logger(logger)
	verse.log = logger;
	server.setlogger(logger);
end

function verse.filter_log(levels, logger)
	local level_set = {};
	for _, level in ipairs(levels) do
		level_set[level] = true;
	end
	return function (level, name, ...)
		if level_set[level] then
			return logger(level, name, ...);
		end
	end;
end

local function error_handler(err)
	verse.log("error", "Error: %s", err);
	verse.log("error", "Traceback: %s", debug.traceback());
end

function verse.set_error_handler(new_error_handler)
	error_handler = new_error_handler;
end

function verse.loop()
	return xpcall(server.loop, error_handler);
end

function verse.step()
	return xpcall(server.step, error_handler);
end

function verse.quit()
	return server.setquitting(true);
end

function stream:connect(connect_host, connect_port)
	connect_host = connect_host or "localhost";
	connect_port = tonumber(connect_port) or 5222;
	
	-- Create and initiate connection
	local conn = socket.tcp()
	conn:settimeout(0);
	local success, err = conn:connect(connect_host, connect_port);
	
	if not success and err ~= "timeout" then
		self:warn("connect() to %s:%d failed: %s", connect_host, connect_port, err);
		return self:event("disconnected", { reason = err }) or false, err;
	end

	local conn = server.wrapclient(conn, connect_host, connect_port, new_listener(self), "*a");
	if not conn then
		self:warn("connection initialisation failed: %s", err);
		return self:event("disconnected", { reason = err }) or false, err;
	end
	
	self.conn = conn;
	self.send = function (stream, data)
		self:event("outgoing", data);
		data = tostring(data);
		self:event("outgoing-raw", data);
		return conn:write(data);
	end;
	return true;
end

function stream:close()
	if not self.conn then 
		verse.log("error", "Attempt to close disconnected connection - possibly a bug");
		return;
	end
	local on_disconnect = self.conn.disconnect();
	self.conn:close();
	on_disconnect(conn, reason);
end

-- Logging functions
function stream:debug(...)
	if self.logger and self.log.debug then
		return self.logger("debug", ...);
	end
end

function stream:warn(...)
	if self.logger and self.log.warn then
		return self.logger("warn", ...);
	end
end

function stream:error(...)
	if self.logger and self.log.error then
		return self.logger("error", ...);
	end
end

function stream:set_logger(logger, levels)
	local old_logger = self.logger;
	if logger then
		self.logger = logger;
	end
	if levels then
		if levels == true then
			levels = { "debug", "info", "warn", "error" };
		end
		self.log = {};
		for _, level in ipairs(levels) do
			self.log[level] = true;
		end
	end
	return old_logger;
end

function stream_mt:set_log_levels(levels)
	self:set_logger(nil, levels);
end

-- Event handling
function stream:event(name, ...)
	self:debug("Firing event: "..tostring(name));
	return self.events.fire_event(name, ...);
end

function stream:hook(name, ...)
	return self.events.add_handler(name, ...);
end

function stream:unhook(name, handler)
	return self.events.remove_handler(name, handler);
end

function verse.eventable(object)
        object.events = events.new();
        object.hook, object.unhook = stream.hook, stream.unhook;
        local fire_event = object.events.fire_event;
        function object:event(name, ...)
                return fire_event(name, ...);
        end
        return object;
end

function stream:add_plugin(name)
	if self.plugins[name] then return true; end
	if require("verse.plugins."..name) then
		local ok, err = verse.plugins[name](self);
		if ok ~= false then
			self:debug("Loaded %s plugin", name);
			self.plugins[name] = true;
		else
			self:warn("Failed to load %s plugin: %s", name, err);
		end
	end
	return self;
end

-- Listener factory
function new_listener(stream)
	local conn_listener = {};
	
	function conn_listener.onconnect(conn)
		stream.connected = true;
		stream:event("connected");
	end
	
	function conn_listener.onincoming(conn, data)
		stream:event("incoming-raw", data);
	end
	
	function conn_listener.ondisconnect(conn, err)
		stream.connected = false;
		stream:event("disconnected", { reason = err });
	end

	function conn_listener.ondrain(conn)
		stream:event("drained");
	end
	
	function conn_listener.onstatus(conn, new_status)
		stream:event("status", new_status);
	end
	
	return conn_listener;
end


local log = require "util.logger".init("verse");

return verse;
