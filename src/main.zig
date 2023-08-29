const std = @import("std");
const time = std.time;
const heap = std.heap;
const process = std.process;
const io = std.io;
const mem = std.mem;
const testing = std.testing;
const timezones = @import("timezones.zig");
const format = @import("format.zig");

const ArgumentsError = error{ UnexpectedFlag, MissingFlag, MissingTemplate, UnsupportedTimezone };

pub fn main() !void {
    const now = time.timestamp();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var allocator = arena.allocator();

    var tzdb = try timezones.TimezoneDB.new(allocator);

    var args = try process.ArgIterator.initWithAllocator(allocator);
    _ = args.skip();
    const flag = args.next() orelse return error.MissingFlag;
    if (!mem.eql(u8, flag, "-t")) {
        return error.UnexpectedFlag;
    }
    const template = args.next() orelse return error.MissingTemplate;

    var isParsingCity = false;
    var out = std.ArrayList(u8).init(allocator);
    var city = std.ArrayList(u8).init(allocator);
    var citiesSoFar: i8 = 0;

    for (template) |char| {
        if (char == '{' and !isParsingCity) {
            isParsingCity = true;
        } else if (char == '}' and isParsingCity) {
            isParsingCity = false;
            const cityTime = try tzdb.timeAt(now, city.items);
            try appendIsoTime(allocator, cityTime, &out, citiesSoFar == 0);
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

fn appendIsoTime(allocator: mem.Allocator, timestamp: i64, outBuffer: *std.ArrayList(u8), includeSeconds: bool) !void {
    const isoTime = try format.time(allocator, timestamp, .{ .includeSeconds = includeSeconds });
    defer allocator.free(isoTime);
    try outBuffer.appendSlice(isoTime);
}

test {
    testing.refAllDecls(@This());
}
