const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const FormatOps = struct {
    includeSeconds: bool = false,
};

pub fn time(allocator: mem.Allocator, now: i64, opts: FormatOps) ![]u8 {
    const seconds: u64 = @intCast(@rem(now, 60));
    const minutes: u64 = @intCast(@rem(@divFloor(now, 60), 60));
    const hours: u64 = @intCast(@rem(@divFloor(now, 3600), 24));

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
        const isoTime = try time(allocator, tc.instant, opts);
        try testing.expectEqualStrings(tc.expected, isoTime);
        testing.allocator.free(isoTime);
    }
}
