const std = @import("std");
const json = std.json;
const mem = std.mem;
const heap = std.heap;
const testing = std.testing;
const format = @import("format.zig");

const timezoneJson = @embedFile("data/timezones.json");
const aliasesJson = @embedFile("data/aliases.json");

const OffsetTime = f16;

const TimezoneMap = std.StringArrayHashMap(OffsetTime);

const AliasMap = std.StringArrayHashMap([]const u8);

const TimezoneError = error{UnsupportedTimezone};

pub const TimezoneDB = struct {
    timezones: TimezoneMap,
    aliases: AliasMap,

    pub fn new(allocator: mem.Allocator) !@This() {
        const timezoneList = try json.parseFromSlice(TimezoneList, allocator, timezoneJson, .{});
        defer timezoneList.deinit();

        var timezoneAliases = try json.parseFromSlice(json.ArrayHashMap([]const u8), allocator, aliasesJson, .{});
        defer timezoneAliases.deinit();

        var timezones = TimezoneMap.init(allocator);
        var aliases = AliasMap.init(allocator);

        for (timezoneList.value.timezones) |timezone| {
            const offset = timezone.offset;
            try timezones.put(timezone.abbr, offset);

            for (timezone.utc) |alias| {
                try timezones.put(alias, offset);
            }
        }

        const entries = timezoneAliases.value.map.entries;

        for (0..entries.len) |i| {
            const entry = entries.get(i);
            try aliases.put(entry.key, entry.value);
        }

        // for (timezoneAliases.map.entries) |entry| {
        //     try aliases.put(entry[0], entry[1]);
        // }
        return @This(){ .timezones = timezones, .aliases = aliases };
    }

    fn find(self: @This(), nameOrAlias: []const u8) ?OffsetTime {
        const name = self.aliases.get(nameOrAlias) orelse nameOrAlias;
        return self.timezones.get(name);
    }

    pub fn timeAt(self: @This(), now: i64, city: []const u8) !i64 {
        const offset = self.find(city) orelse return error.UnsupportedTimezone;
        const secondsDelta = @as(i64, @intFromFloat(offset)) * 3600;
        return now + secondsDelta;
    }
};

const TimezoneAliases = struct { aliases: AliasMap };

const TimezoneList = struct { timezones: []const Timezones };

const Timezones = struct {
    value: []const u8,
    abbr: []const u8,
    offset: OffsetTime,
    isdst: bool,
    text: []const u8,
    utc: []const []const u8,
};

test "parsing" {
    const tz =
        \\ {
        \\   "value": "Myanmar Standard Time",
        \\   "abbr": "MST",
        \\   "offset": 6.5,
        \\   "isdst": false,
        \\   "text": "(UTC+06:30) Yangon (Rangoon)",
        \\   "utc": [
        \\     "Asia/Rangoon",
        \\     "Indian/Cocos"
        \\   ]
        \\ }
    ;
    const allocator = testing.allocator;
    const actual = try std.json.parseFromSlice(Timezones, allocator, tz, .{});
    defer actual.deinit();
    const expected = Timezones{ .value = "Myanmar Standard Time", .abbr = "MST", .offset = 6.5, .isdst = false, .text = "(UTC+06:30) Yangon (Rangoon)", .utc = &[_][]const u8{ "Asia/Rangoon", "Indian/Cocos" } };
    try testing.expectEqualDeep(expected, actual.value);
}

test "aliases" {
    const allocator = testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const tzdb = try TimezoneDB.new(arena.allocator());
    const now = 100_000;

    const nycTime = try tzdb.timeAt(now, "NYC");
    const edtTime = try tzdb.timeAt(now, "EDT");

    try testing.expectEqual(edtTime, nycTime);
}

test "timezone offset" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const tzdb = try TimezoneDB.new(allocator);
    const now = 1_693_307_510; // Tue Aug 29 2023 13:11:50 GMT+0200 (Central European Summer Time)

    inline for (.{
        .{ .expected = "13:11:50", .city = "BCN" },
        .{ .expected = "08:11:50", .city = "BUE" },
        .{ .expected = "07:11:50", .city = "NYC" },
        .{ .expected = "06:11:50", .city = "CHI" },
    }) |tc| {
        const instant = try tzdb.timeAt(now, tc.city);
        const isoTime = try format.time(allocator, instant, .{ .includeSeconds = true });
        try testing.expectEqualStrings(tc.expected, isoTime);
    }
}
