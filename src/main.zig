const std = @import("std");
const time = std.time;
const heap = std.heap;
const process = std.process;
const io = std.io;
const mem = std.mem;
const testing = std.testing;
const hash_map = std.hash_map;

const ArgumentsError = error{ UnexpectedFlag, MissingFlag, MissingTemplate, UnsupportedTimezone };

const Timezone = enum(i64) {
    PT = timezone(Offset{ .hours = -7 }), // SF
    CT = timezone(Offset{ .hours = -6 }), // Chicago
    ET = timezone(Offset{ .hours = -5 }), // NY
    BUE = timezone(Offset{ .hours = -4 }),
    BCN = timezone(Offset{ .hours = 1 }),

    pub fn at(self: Timezone, now: i64) i64 {
        return @enumToInt(self) + now;
    }
};

const Offset = struct {
    hours: i8,
    minutes: i8 = 0,
};

fn timezone(offset: Offset) i64 {
    return @intCast(i64, offset.hours) * 3600 + @intCast(i64, offset.minutes) * 60;
}

pub fn main() !void {
    const now = time.timestamp();

    const allocator = heap.page_allocator;

    var timezones = std.StringArrayHashMap(i64).init(heap.page_allocator);
    defer timezones.deinit();

    for (std.enums.values(Timezone)) |tz| {
        const tzName = @tagName(tz);
        const tzValue = @enumToInt(tz);
        try timezones.put(tzName, tzValue);
    }

    var args = try process.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();
    const flag = args.next() orelse return error.MissingFlag;

    if (!mem.eql(u8, flag, "-f")) {
        return error.UnexpectedFlag;
    }
    const format = args.next() orelse return error.MissingTemplate;

    var isParsingCity = false;
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    var city = std.ArrayList(u8).init(allocator);
    var citiesSoFar: i8 = 0;

    for (format) |char| {
        if (char == '{' and !isParsingCity) {
            isParsingCity = true;
        } else if (char == '}' and isParsingCity) {
            isParsingCity = false;
            try appendIsoTime(allocator, now, city.items, &timezones, &out, citiesSoFar == 0);
            city.clearAndFree();
            citiesSoFar += 1;
        } else if (isParsingCity) {
            try city.append(char);
        } else {
            try out.append(char);
        }
    }

    const stdout = io.getStdOut().writer();
    try stdout.print("{s}", .{out.items});
}

fn appendIsoTime(allocator: mem.Allocator, now: i64, cityName: []const u8, timezones: *std.StringArrayHashMap(i64), outBuffer: *std.ArrayList(u8), includeSeconds: bool) !void {
    const tzDelta = timezones.get(cityName) orelse return error.UnsupportedTimezone;
    const isoTime = try formatTime(allocator, now + tzDelta, .{ .includeSeconds = includeSeconds });
    try outBuffer.appendSlice(isoTime);
    allocator.free(isoTime);
}

const FormatOps = struct {
    includeSeconds: bool = false,
};

fn formatTime(allocator: mem.Allocator, now: i64, opts: FormatOps) ![]u8 {
    const seconds = @intCast(u64, @rem(now, 60));
    const minutes = @intCast(u64, @rem(@divFloor(now, 60), 60));
    const hours = @intCast(u64, @rem(@divFloor(now, 3600), 24));

    if (opts.includeSeconds) {
        return try std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds });
    } else {
        return try std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2}", .{ hours, minutes });
    }
}

test "formatting" {
    const opts = .{ .includeSeconds = true };
    const allocator = testing.allocator;
    inline for (.{
        .{ .expected = "00:00:00", .instant = 0 },
        .{ .expected = "00:00:39", .instant = 39 },
        .{ .expected = "00:01:01", .instant = 61 },
        .{ .expected = "01:00:00", .instant = 3600 },
        .{ .expected = "01:01:01", .instant = 3661 },
        .{ .expected = "13:54:05", .instant = 50_045 },
        .{ .expected = "13:46:40", .instant = 1_000_000 },
    }) |tc| {
        const isoTime = try formatTime(allocator, tc.instant, opts);
        try testing.expectEqualStrings(tc.expected, isoTime);
        testing.allocator.free(isoTime);
    }
}

test "timezone offset" {
    const now = 100_000;
    try testing.expectEqual(@as(i64, 82_000), Timezone.ET.at(now)); // -5 * 3600 + 100_000
}
