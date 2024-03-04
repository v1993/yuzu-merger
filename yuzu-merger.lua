local json = require 'json'
local https = require 'ssl.https'
local ltn12 = require 'ltn12'
local posix = require 'posix'

-- Hack to let it work on Lua <= 5.3 (untested)
if not math.maxinteger then
	math.maxinteger = math.huge
end

local function requestIssuesPaged(page, label, all)
	local response_body = {}
	local token = os.getenv 'YUZU_MERGER_TOKEN'

	local res, code, response_headers = https.request {
		url = table.concat {'https://api.github.com/repos/yuzu-emu/yuzu/issues',
			('?state=%s'):format(all and "all" or "open");
			(label and
				'&labels='..label or
				''
			);
			'&sort=created';
			'&direction=asc'; -- `asc` makes more sense, official merger uses `desc`
			'&per_page=100'; -- Can be set to any acceptable value
			('&page=%d'):format(page);
		};
		sink = ltn12.sink.table(response_body);
		method = 'GET';

		headers = {
			Accept = 'application/vnd.github.v3.text+json';
			Authorization = token and (('token %s'):format(token));
		}
	}

	assert(res, code)

	--print(table.concat(response_body))
	return table.concat(response_body)
end

local function forEachIssue(callback, label, all)
	for i=1, math.maxinteger do
		local data = json.decode(requestIssuesPaged(i, label, all))

		if #data == 0 then break end

		for k, issue in ipairs(data) do
			callback(issue, label)
		end
	end
end

local function gitCommand(ignore_errors, ...)
	local code = assert(posix.spawn({'git', ...}))

	if (code ~= 0 and not ignore_errors) then
		io.stderr:write(([[Git command `%s' failed, terminating
]]):format(table.concat({...}, ' ')))
		os.exit(true, true)
	end

	return code == 0
end

local function mergePr(pr, mergeType)
	if not pr.pull_request then
		print(('Issue %d is not a Pull Request!!!'):format(pr.number))
		return
	end

	print(('Merging PR #%d: %s'):format(pr.number, pr.title))

	gitCommand(false, 'fetch', '-f', '--recurse-submodules', '-j5', 'origin', ('pull/%d/head:yuzu-merger-pr%d'):format(pr.number, pr.number))
	gitCommand(false, 'merge', '--no-gpg-sign', '-m', ('yuzu-merger %s: PR #%d: %s'):format(mergeType, pr.number, pr.title), ('yuzu-merger-pr%d'):format(pr.number))
end

local function applyPatches(label)
	forEachIssue(mergePr, label)
end

local prToMerge = ...

if not prToMerge then
	-- Normal mode: update and merge

	print('Resetting local changes')
	if not gitCommand(true, 'reset', '--hard', 'origin/master') then
		print('Failed to undo local changes. Make sure that you are in correct directory and try again')
		return
	end

	print('Pulling new changes')
	gitCommand(false, 'pull', '--prune')

	do
		::requestion::
		io.write('Do you want to apply mainline patches? [Yn]: ')
		local res = io.read 'l'

		if res == '' or res:lower() == 'y' then
			applyPatches('mainline-merge')
			print('Mainline patches applied')
		elseif res:lower() == 'n' then
			-- Do nothing
		else
			goto requestion
		end
	end

	do
		::requestion::
		io.write('Do you want to apply early access patches? [yN]: ')
		local res = io.read 'l'

		if res:lower() == 'y' then
			applyPatches('early-access-merge')
			print('Early access patches applied. Please consider using Patreon to support Yuzu team!')
		elseif res == '' or res:lower() == 'n' then
			-- Do nothing
		else
			goto requestion
		end
	end
else
	-- Manual mode: merge specific patch
	-- Let's assume that PRs have sensible names
	if prToMerge:sub(1,1) == '#' then
		prToMerge = assert(math.tointeger(prToMerge:sub(2,-1)), 'invalid PR number')
		print(('Searching for PR #%d'):format(prToMerge))
	elseif prToMerge == 'mainline' then
		applyPatches('mainline-merge')
		print('Mainline patches applied per request')
		goto done
	elseif prToMerge == 'ea' then
		applyPatches('early-access-merge')
		print('Early access patches applied per request')
		goto done
	else
		print(('Searching for PR named "%s"'):format(prToMerge))
	end

	-- FIXME: this is dumb and slow
	forEachIssue(function(pr)
		if pr.title == prToMerge or pr.number == prToMerge then
			mergePr(pr, "MANUAL")
		end
	end,
	nil,
	--true
	false
	)
	::done::
end

print('Finishing up: updating submodules')
gitCommand(false, 'submodule', 'sync', '--recursive')
gitCommand(false, 'submodule', 'update', '--recursive', '--init')
