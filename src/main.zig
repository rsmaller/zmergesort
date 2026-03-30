const std = @import("std");
const sort = @import("sort.zig");

pub fn main() !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    var stdout = &stdout_writer.interface;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        if (gpa.deinit() == std.heap.Check.leak) {
            std.debug.print("Aaaaa leak\n", .{});
        }
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 2) {
        try stdout.print("Please provide an argument.\n", .{});
        try stdout.flush();
        return;
    }
    const n = try std.fmt.parseInt(u32, args[1], 10);
    const random_buf = try allocator.alloc(u32, n);
    defer allocator.free(random_buf);

    var results: [9]sort.SortResult = undefined;
    var resultIndex: usize = 0;

    results[resultIndex] = try sort.test_sorter("Counting Sort", allocator, sort.counting_sort, stdout, random_buf);
    resultIndex += 1;

    results[resultIndex] = try sort.test_sorter("Merge Sort Recursive", allocator, sort.merge_sort_recursive, stdout, random_buf);
    resultIndex += 1;

    results[resultIndex] = try sort.test_sorter("Merge Sort Stack", allocator, sort.merge_sort_stack, stdout, random_buf);
    resultIndex += 1;

    results[resultIndex] = try sort.test_sorter("Merge Sort Loop", allocator, sort.merge_sort_loop, stdout, random_buf);
    resultIndex += 1;

    results[resultIndex] = try sort.test_sorter("Quick Sort Recursive", allocator, sort.quick_sort_recursive, stdout, random_buf);
    resultIndex += 1;

    results[resultIndex] = try sort.test_sorter("Quick Sort Stack", allocator, sort.quick_sort_stack, stdout, random_buf);
    resultIndex += 1;

    if (n <= 64000) {
        results[resultIndex] = try sort.test_sorter("Insertion Sort", allocator, sort.insertion_sort, stdout, random_buf);
        resultIndex += 1;

        results[resultIndex] = try sort.test_sorter("Selection Sort", allocator, sort.selection_sort, stdout, random_buf);
        resultIndex += 1;

        results[resultIndex] = try sort.test_sorter("Bubble Sort", allocator, sort.bubble_sort, stdout, random_buf);
        resultIndex += 1;
    }

    try sort.merge_sort_loop(allocator, results[0..resultIndex]);
    try stdout.print("In order of speed: ", .{});
    for (0..resultIndex - 1) |i| {
        try stdout.print("{s} ({:.0}/s), ", .{ results[i].name, results[i].efficiency });
    }
    try stdout.print("then {s} ({:.0}/s).", .{ results[resultIndex - 1].name, results[resultIndex - 1].efficiency });
    try stdout.print("\n", .{});
    try stdout.flush();
}
