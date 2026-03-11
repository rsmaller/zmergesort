const std = @import("std");
const sort = @import("sort.zig");

pub fn main() !void {
    var stdout_buf : [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    var stdout = &stdout_writer.interface;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 2) {
        try stdout.print("Please provide an argument.\n", .{});
        try stdout.flush();
        return;
    }
    const n = try std.fmt.parseInt(u32, args[1], 10);
    const random_buf = try allocator.alloc(u16, n);

    random_buf[0] = 1;
    for (0..random_buf.len) |i| {
        random_buf[i] = std.crypto.random.intRangeAtMost(u16, 0, 100);
    }

    var results: [6]sort.SortResult = undefined;
    var resultIndex: usize = 0;

    results[resultIndex] = try sort.test_sorter("Merge Sort Loop", allocator, sort.merge_sort_loop, stdout, random_buf);
    resultIndex += 1;

    results[resultIndex] = try sort.test_sorter("Insertion Sort", allocator, sort.insertion_sort, stdout, random_buf);
    resultIndex += 1;

    results[resultIndex] = try sort.test_sorter("Selection Sort", allocator, sort.selection_sort, stdout, random_buf);
    resultIndex += 1;

    results[resultIndex] = try sort.test_sorter("Bubble Sort", allocator, sort.bubble_sort, stdout, random_buf);
    resultIndex += 1;

    results[resultIndex] = try sort.test_sorter("Merge Sort Recursive", allocator, sort.merge_sort_recursive, stdout, random_buf);
    resultIndex += 1;

    results[resultIndex] = try sort.test_sorter("Merge Sort Stack", allocator, sort.merge_sort_stack, stdout, random_buf);
    resultIndex += 1;

    try sort.merge_sort_loop(allocator, &results);
    try stdout.print("In order of speed: ", .{});
    for (0..results.len-1) |i| {
        try stdout.print("{s}, ", .{results[i].name});
    }
    try stdout.print("then {s}.", .{results[results.len-1].name});
    try stdout.print("\n", .{});
    try stdout.flush();
}