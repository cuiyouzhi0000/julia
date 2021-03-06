## semantic version numbers (http://semver.org)

type VersionNumber
    major::Int
    minor::Int
    patch::Int
    prerelease::Vector{Union(Int,ASCIIString)}
    build::Vector{Union(Int,ASCIIString)}

    function VersionNumber(major::Int, minor::Int, patch::Int, pre::Vector, bld::Vector)
        if major < 0; error("invalid major version: $major"); end
        if minor < 0; error("invalid minor version: $minor"); end
        if patch < 0; error("invalid patch version: $patch"); end
        prerelease = Array(Union(Int,ASCIIString),length(pre))
        for i in 1:length(pre)
            ident = ascii(string(pre[i]))
            if !matches(r"^(?:[0-9a-z-]+)?$"i, ident)
                error("invalid pre-release identifier: $ident")
            end
            if matches(r"^\d+$", ident)
                ident = parse_int(ident)
            end
            prerelease[i] = ident
        end
        build = Array(Union(Int,ASCIIString),length(bld))
        for i in 1:length(bld)
            ident = ascii(string(bld[i]))
            if !matches(r"^(?:[0-9a-z-]+)?$"i, ident)
                error("invalid build identifier: $ident")
            end
            if matches(r"^\d+$", ident)
                ident = parse_int(ident)
            end
            build[i] = ident
        end
        new(major, minor, patch, prerelease, build)
    end
end
VersionNumber(x::Integer, y::Integer, z::Integer) = VersionNumber(x, y, z, [], [])
VersionNumber(x::Integer, y::Integer)             = VersionNumber(x, y, 0, [], [])
VersionNumber(x::Integer)                         = VersionNumber(x, 0, 0, [], [])

function print(v::VersionNumber)
    print(v.major)
    print('.')
    print(v.minor)
    print('.')
    print(v.patch)
    if !isempty(v.prerelease)
        print('-')
        print_joined(v.prerelease,'.')
    end
    if !isempty(v.build)
        print('+')
        print_joined(v.build,'.')
    end
end
show(v::VersionNumber) = print("v\"",v,"\"")

convert(::Type{VersionNumber}, v::Integer) = VersionNumber(v)
convert(::Type{VersionNumber}, v::Tuple) = VersionNumber(v...)

const VERSION_REGEX = r"^
    v?                                      # prefix        (optional)
    (\d+)                                   # major         (required)
    (?:\.(\d+))?                            # minor         (optional)
    (?:\.(\d+))?                            # patch         (optional)
    (?:-((?:[0-9a-z-]+\.)*[0-9a-z-]+))?     # pre-release   (optional)
    (?:\+((?:[0-9a-z-]+\.)*[0-9a-z-]+))?    # build         (optional)
$"ix

function convert(::Type{VersionNumber}, v::String)
    m = match(VERSION_REGEX, v)
    if m == nothing; error("invalid version string: $v"); end
    major, minor, patch, prerl, build = m.captures
    major = parse_int(major)
    minor = minor==nothing ?  0 : parse_int(minor)
    patch = patch==nothing ?  0 : parse_int(patch)
    prerl = prerl==nothing ? [] : split(prerl,'.')
    build = build==nothing ? [] : split(build,'.')
    VersionNumber(major, minor, patch, prerl, build)
end

macro v_str(v); convert(VersionNumber, v); end

_jl_ident_cmp(a::Int, b::Int) = cmp(a,b)
_jl_ident_cmp(a::Int, b::ASCIIString) = -1
_jl_ident_cmp(a::ASCIIString, b::Int) = +1
_jl_ident_cmp(a::ASCIIString, b::ASCIIString) = cmp(a,b)

function _jl_ident_cmp(A::Vector{Union(Int,ASCIIString)},
                       B::Vector{Union(Int,ASCIIString)})
    i = start(A)
    j = start(B)
    while !done(A,i) && !done(B,i)
       a,i = next(A,i)
       b,j = next(B,j)
       c = _jl_ident_cmp(a,b)
       (c != 0) && return c
    end
    done(A,i) && !done(B,j) ? -1 :
    !done(A,i) && done(B,j) ? +1 : 0
end

function isequal(a::VersionNumber, b::VersionNumber)
    (a.major != b.major) && return false
    (a.minor != b.minor) && return false
    (a.patch != b.patch) && return false
    (_jl_ident_cmp(a.prerelease,b.prerelease) != 0) && return false
    (_jl_ident_cmp(a.build,b.build) != 0) && return false
    return true
end

function isless(a::VersionNumber, b::VersionNumber)
    (a.major < b.major) && return true
    (a.major > b.major) && return false
    (a.minor < b.minor) && return true
    (a.minor > b.minor) && return false
    (a.patch < b.patch) && return true
    (a.patch > b.patch) && return false
    (!isempty(a.prerelease) && isempty(b.prerelease)) && return true
    (isempty(a.prerelease) && !isempty(b.prerelease)) && return false
    c = _jl_ident_cmp(a.prerelease,b.prerelease)
    (c < 0) && return true
    (c > 0) && return false
    c = _jl_ident_cmp(a.build,b.build)
    (c < 0) && return true
    return false
end

## julia version info

const VERSION = convert(VersionNumber,chomp(readall(open("$JULIA_HOME/VERSION"))))
const VERSION_COMMIT = chomp(readall(`git rev-parse HEAD`))
const VERSION_CLEAN = success(`git diff --quiet`)
const VERSION_TIME = strftime("%F %T",int(readall(`git log -1 --pretty=format:%ct`)))

begin

const _jl_version_string = "Version $VERSION"
local _jl_version_clean = VERSION_CLEAN ? "" : "*"
const _jl_commit_string = "Commit $(VERSION_COMMIT[1:10]) ($VERSION_TIME)$_jl_version_clean"

const _jl_banner_plain =
I"               _
   _       _ _(_)_     |
  (_)     | (_) (_)    |  A fresh approach to technical computing
   _ _   _| |_  __ _   |
  | | | | | | |/ _` |  |  $_jl_version_string
  | | |_| | | | (_| |  |  $_jl_commit_string
 _/ |\__'_|_|_|\__'_|  |
|__/                   |

"

local tx = "\033[0m\033[1m" # text
local jl = "\033[0m\033[1m" # julia
local d1 = "\033[34m" # first dot
local d2 = "\033[31m" # second dot
local d3 = "\033[32m" # third dot
local d4 = "\033[35m" # fourth dot
const _jl_banner_color =
"\033[1m               $(d3)_
   $(d1)_       $(jl)_$(tx) $(d2)_$(d3)(_)$(d4)_$(tx)     |
  $(d1)(_)$(jl)     | $(d2)(_)$(tx) $(d4)(_)$(tx)    |  A fresh approach to technical computing
   $(jl)_ _   _| |_  __ _$(tx)   |
  $(jl)| | | | | | |/ _` |$(tx)  |  $_jl_version_string
  $(jl)| | |_| | | | (_| |$(tx)  |  $_jl_commit_string
 $(jl)_/ |\\__'_|_|_|\\__'_|$(tx)  |
$(jl)|__/$(tx)                   |

\033[0m"

end # begin
