math.randomseed(os.time())

local headers = ngx.req.get_headers()
local pattern_type  = headers["X-Pattern-Type"]
local card_number   = headers["X-Card-Number"]
local tokenized_card_number = headers["X-Tokenized-Card-Number"]
local pattern_count = tonumber(headers["X-Pattern-Count"]) or 0
local payload_size  = tonumber(headers["X-Pattern-Bytes"]) or 0
local debug_header  = tostring(headers["X-Pattern-Debug"])
local x_request_id_header = tostring(headers["X-Request-Id"])


-- Validate headers
if not pattern_type or not card_number or not tokenized_card_number or pattern_count <= -1 or payload_size <= 0 then
    ngx.status = 400
    ngx.say("Missing required headers or invalid numbers")
    return
end

-- Determine pattern string
local pattern_string
if pattern_type == "AccountActivity" then
    pattern_string = string.format('<AccountActivity accountNumber="%s">', tokenized_card_number)
elseif pattern_type == "PCard" then
    pattern_string = string.format('<PCard number="%s">', tokenized_card_number)
else
    ngx.status = 400
    ngx.say("Invalid pattern type")
    return
end

local pattern_len = #pattern_string
if pattern_count * pattern_len > payload_size then
    ngx.status = 422
    ngx.say("❌ ERROR: Cannot fit patterns into payload size")
    return
end

-- Fill payload with random alphanumeric characters
local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
local filler = {}
for i = 1, payload_size do
    local rand = math.random(1, #charset)
    filler[i] = string.sub(charset, rand, rand)
end

-- Insert patterns at random positions
local inserted = 0
local attempts = 0
while inserted < pattern_count and attempts < payload_size * 10 do
    attempts = attempts + 1
    local pos = math.random(1, payload_size - pattern_len + 1)
    local empty_space = true
    for j = 0, pattern_len - 1 do
        if filler[pos + j] == pattern_string:sub(1,1) then
            empty_space = false
            break
        end
    end
    if empty_space then
        for j = 1, pattern_len do
            filler[pos + j - 1] = pattern_string:sub(j,j)
        end
        inserted = inserted + 1
    end
end

local result = table.concat(filler)

-- Base64 encode result so k6 can safely handle it as UTF-8
-- local b64_result = ngx.encode_base64(result)

ngx.header["X-Detokenize"] = "true"
ngx.header["Content-Type"] = "text/plain; charset=utf-8"
ngx.header["Content-Length"] = #result   -- must match actual body length
ngx.header["X-Patterns-Num"] = inserted
ngx.header["X-Pattern-Type"] = pattern_type
ngx.header["X-Card-Number"] = card_number
ngx.header["X-Debug-Mode"] = debug_header
ngx.header["request-id"] = x_request_id_header

if debug_header == "true" then
    ngx.log(ngx.ERR, "DEBUG: Inserted " .. inserted .. " patterns")
    ngx.log(ngx.ERR, "DEBUG: Raw first 200 chars: " .. string.sub(result, 1, 200))
    -- ngx.log(ngx.ERR, "DEBUG: Raw first b64_result 200 chars: " .. string.sub(b64_result, 1, 200))
    ngx.log(ngx.ERR, "DEBUG: Result length: " .. #result)
end

ngx.say(result)