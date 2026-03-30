const std = @import("std");

const StackError = error{EmptyStack};

const MergeSortFrame = struct {
    left: usize,
    right: usize,
    state: enum {
        NO_RECURSE,
        AFTER_LEFT,
        AFTER_RIGHT,
    },
};

pub const SortResult = struct {
    const Self = @This();
    time_seconds: f128,
    data_size: usize,
    efficiency: f128,
    name: []const u8,

    pub inline fn compare(a: *const Self, b: SortResult, eq: Equality) bool {
        return numeric_comparator(a.time_seconds, b.time_seconds, eq);
    }
};

pub const Equality = enum {
    EQ,
    NE,
    LE,
    GE,
    GT,
    LT,
};

fn SortStack(comptime T: type) type {
    return struct {
        const Self = @This();
        current_index: usize = 0,
        capacity: usize = 4,
        allocation: []T = undefined,

        pub fn push(self: *Self, allocator: anytype, item: T) !void {
            if (self.current_index == self.capacity) {
                self.capacity = self.capacity * 2;
                if (!allocator.resize(self.allocation, self.capacity)) {
                    self.allocation = try allocator.realloc(self.allocation, self.capacity);
                }
            }
            self.allocation[self.current_index] = item;
            self.current_index += 1;
        }

        pub fn pop(self: *Self) !T {
            if (self.current_index == 0) return StackError.EmptyStack;
            self.current_index -= 1;
            const ret = self.allocation[self.current_index];
            return ret;
        }

        pub fn deinit(self: *Self, allocator: anytype) void {
            allocator.free(self.allocation);
        }

        pub fn top(self: *Self) !T {
            if (self.current_index == 0) return StackError.EmptyStack;
            return self.allocation[self.current_index - 1];
        }

        pub fn top_ptr(self: *Self) !*T {
            if (self.current_index == 0) return StackError.EmptyStack;
            return &self.allocation[self.current_index - 1];
        }
    };
}

fn create_sort_stack(allocator: anytype, comptime T: type) !SortStack(T) {
    var stack = SortStack(T){};
    stack.allocation = try allocator.alloc(T, stack.capacity);
    return stack;
}

fn create_sort_stack_initsize(allocator: anytype, comptime T: type, size: usize) !SortStack(T) {
    var stack = SortStack(T){ .capacity = size };
    stack.allocation = try allocator.alloc(T, stack.capacity);
    return stack;
}

pub inline fn numeric_comparator(a: anytype, b: anytype, eq: Equality) bool {
    switch (eq) {
        .EQ => {
            return a == b;
        },
        .NE => {
            return a != b;
        },
        .GE => {
            return a >= b;
        },
        .LE => {
            return a <= b;
        },
        .GT => {
            return a > b;
        },
        .LT => {
            return a < b;
        },
    }
}

pub inline fn generic_comparator(a: anytype, b: anytype, eq: Equality) bool {
    std.debug.assert(@TypeOf(a) == @TypeOf(b));
    switch (@typeInfo(@TypeOf(a))) {
        .@"struct" => {
            return a.compare(b, eq);
        },
        else => {
            return numeric_comparator(a, b, eq);
        },
    }
}

pub inline fn shuffle(buf: anytype) void {
    for (0..buf.len) |i| {
        const swapIndex = std.crypto.random.intRangeAtMost(usize, 0, buf.len - 1);
        const temp = buf[i];
        buf[i] = buf[swapIndex];
        buf[swapIndex] = temp;
    }
}

pub inline fn reversed_identity(buf: anytype) void {
    const T = @TypeOf(buf[0]);
    const max = std.math.maxInt(T);
    if (buf.len > max) {
        for (0..buf.len) |i| {
            if (max < i + 1) {
                buf[i] = 0;
                continue;
            }
            buf[i] = @as(T, @intCast(max - i - 1));
        }
    } else {
        for (0..buf.len) |i| {
            buf[i] = @as(T, @intCast(buf.len - i - 1));
        }
    }
}

pub inline fn randomize(buf: anytype, min: anytype, max: anytype) void {
    for (0..buf.len) |i| {
        buf[i] = std.crypto.random.intRangeAtMost(@TypeOf(buf[i]), min, max);
    }
}

pub fn merge_sort_stack(allocator: anytype, buf: anytype) !void {
    const tempbuf = try allocator.alloc(@TypeOf(buf[0]), buf.len);
    defer allocator.free(tempbuf);
    const stack_size: usize = std.math.log2_int_ceil(usize, buf.len) * 2;
    var stack = try create_sort_stack_initsize(allocator, MergeSortFrame, stack_size);
    defer stack.deinit(allocator);
    try stack.push(allocator, .{ .left = 0, .right = buf.len - 1, .state = .NO_RECURSE });
    while (stack.current_index > 0) {
        var current_frame = try stack.top_ptr();
        const left: usize = current_frame.left;
        const right: usize = current_frame.right;
        const middle = (right + left) / 2;
        switch (current_frame.state) {
            .NO_RECURSE => {
                if (left >= right) {
                    _ = try stack.pop();
                    continue;
                }
                current_frame.state = .AFTER_LEFT;
                try stack.push(allocator, .{ .left = left, .right = middle, .state = .NO_RECURSE });
            },
            .AFTER_LEFT => {
                current_frame.state = .AFTER_RIGHT;
                try stack.push(allocator, .{ .left = middle + 1, .right = right, .state = .NO_RECURSE });
            },
            .AFTER_RIGHT => {
                try merge(buf, tempbuf, left, middle, right);
                _ = try stack.pop();
            },
        }
    }
}

pub fn merge_sort_recursive(allocator: anytype, buf: anytype) !void {
    const tempbuf = try allocator.alloc(@TypeOf(buf[0]), buf.len);
    defer allocator.free(tempbuf);
    try merge_sort_recursive_internal(buf, tempbuf, 0, buf.len - 1); // Recurse in another function to permit pre-allocation.
}

fn merge_sort_recursive_internal(buf: anytype, tempbuf: anytype, min: usize, max: usize) !void {
    if (min >= max) return;
    const mid = (min + max) / 2;
    try merge_sort_recursive_internal(buf, tempbuf, min, mid);
    try merge_sort_recursive_internal(buf, tempbuf, mid + 1, max);
    try merge(buf, tempbuf, min, mid, max);
}

pub fn merge_sort_loop(allocator: anytype, buf: anytype) !void {
    const tempbuf = try allocator.alloc(@TypeOf(buf[0]), buf.len);
    defer allocator.free(tempbuf);
    var length: usize = 1;
    const n_inclusive = tempbuf.len;
    const n_non_inclusive = n_inclusive - 1;
    while (length < n_inclusive) : (length *= 2) {
        var min: usize = 0;
        while (min < n_inclusive) : (min += length * 2) {
            const mid = @min(min + length - 1, n_non_inclusive);
            const max = @min(min + length * 2 - 1, n_non_inclusive);
            try merge(buf, tempbuf, min, mid, max);
        }
    }
}

inline fn merge(buf: anytype, tempbuf: anytype, min: usize, mid: usize, max: usize) !void {
    var left = tempbuf.ptr + min;
    const left_len = mid - min + 1;
    if (left_len <= 16) { // Insertion sort fallback for small partitions.
        try insertion_sort(null, buf[min .. max + 1]);
        return;
    }
    @memcpy(left, buf[min .. mid + 1]); // Only use the left side.
    var i: usize = 0;
    var j: usize = mid + 1;
    var buf_ptr = buf.ptr;
    var buf_index: usize = min;
    while (i < left_len and j <= max) : (buf_index += 1) { // Standard merging loop.
        if (generic_comparator(left[i], buf[j], .LE)) {
            buf_ptr[buf_index] = left[i];
            i += 1;
        } else { // Index in-place on the right side.
            buf_ptr[buf_index] = buf_ptr[j];
            j += 1;
        }
    }
    if (i < left_len) { // Right side is in-place; only copy left side over if unfinished.
        @memcpy(buf_ptr + buf_index, left[i..left_len]);
    }
}

pub inline fn insertion_sort(allocator: anytype, buf: anytype) !void {
    _ = allocator; // Here to appease the sorter testing function.
    var buf_ptr = buf.ptr;
    const buf_len = buf.len;
    if (buf_len <= 1) return;
    for (1..buf_len) |i| {
        const key = buf_ptr[i];
        var j = i;
        while (j > 0 and generic_comparator(buf_ptr[j - 1], key, .GT)) {
            buf_ptr[j] = buf_ptr[j - 1];
            j -= 1;
        }
        buf_ptr[j] = key;
    }
}

pub inline fn selection_sort(allocator: anytype, buf: anytype) !void {
    _ = allocator; // Here to appease the sorter testing function.
    var buf_ptr = buf;
    const buf_len = buf.len;
    if (buf_len <= 1) return;
    for (0..buf_len) |i| {
        var current_min: usize = i;
        for (i + 1..buf_len) |j| {
            if (generic_comparator(buf_ptr[j], buf_ptr[current_min], .LT)) {
                current_min = j;
            }
        }
        if (current_min != i) {
            const temp = buf_ptr[current_min];
            buf_ptr[current_min] = buf_ptr[i];
            buf_ptr[i] = temp;
        }
    }
}

pub inline fn bubble_sort(allocator: anytype, buf: anytype) !void {
    _ = allocator;
    var buf_ptr = buf;
    var swapped = true;
    while (swapped) {
        swapped = false;
        for (1..buf.len) |i| {
            if (generic_comparator(buf_ptr[i], buf_ptr[i - 1], .LT)) {
                swapped = true;
                const temp = buf_ptr[i];
                buf_ptr[i] = buf_ptr[i - 1];
                buf_ptr[i - 1] = temp;
            }
        }
    }
}

pub inline fn quick_sort_partition_lomuto(buf: anytype, min: usize, max: usize) usize {
    const key = buf[max]; // Assume pivot is at the end; swap pivot into correct place after.
    var i: usize = min;
    for (min..max) |j| {
        if (generic_comparator(buf[j], key, .LT)) {
            std.mem.swap(@TypeOf(buf[0]), &buf[i], &buf[j]); // Push everything to the back.
            i += 1;
        }
    }
    std.mem.swap(@TypeOf(buf[0]), &buf[i], &buf[max]); // Swap pivot into new correct location.
    return i;
}

pub inline fn int_median(buf: anytype, a: anytype, b: anytype, c: anytype) @TypeOf(a) {
    const x = buf[a];
    const y = buf[b];
    const z = buf[c];
    if (x <= y) {
        if (x >= z) return a; // If x is less than y and greater than z, x is the median.
        if (y <= z) return b; // If y is greater than x and less than z, y is the median.
        return c; // If neither of the above are the median, then z is.
    } else {
        if (x <= z) return a; // If x is greater than y and less than z, x is the median.
        if (y >= z) return b; // If y is less than x and greater than z, y is the median.
        return c; // If neither of the above are the median, then z is.
    }
}

pub inline fn quick_sort_partition_hoare(buf: anytype, min: usize, max: usize) usize {
    var i: usize = min;
    var j: usize = max;
    const mid = (min + max) / 2;
    const best_median = int_median(buf, min, mid, max);
    const pivot = buf[best_median];
    while (true) {
        while (i < max and generic_comparator(buf[i], pivot, .LT)) {
            i += 1;
        }
        while (generic_comparator(buf[j], pivot, .GT)) {
            j -= 1;
        }
        if (generic_comparator(i, j, .GE)) {
            break;
        }
        std.mem.swap(@TypeOf(buf[0]), &buf[i], &buf[j]);
        i += 1;
        j -= 1;
    }
    return j;
}

pub fn quick_sort_recursive(allocator: anytype, buf: anytype) !void {
    try quick_sort_recursive_internal(allocator, buf, 0, buf.len - 1);
}

fn quick_sort_recursive_internal(allocator: anytype, buf: anytype, min: usize, max: usize) !void {
    if (max - min <= 16) {
        try insertion_sort(allocator, buf[min .. max + 1]);
        return;
    }
    var min_side = min;
    while (min_side < max) {
        const new_pivot = quick_sort_partition_hoare(buf, min_side, max);
        try quick_sort_recursive_internal(allocator, buf, min_side, new_pivot);
        min_side = new_pivot + 1;
    }
}

pub fn quick_sort_stack(allocator: anytype, buf: anytype) !void {
    const stack_size: usize = std.math.log2_int_ceil(usize, buf.len) * 2;
    var stack = try create_sort_stack_initsize(allocator, MergeSortFrame, stack_size);
    defer stack.deinit(allocator);
    try stack.push(allocator, .{ .left = 0, .right = buf.len - 1, .state = .NO_RECURSE });
    while (stack.current_index > 0) {
        const current_frame = try stack.pop();
        const left: usize = current_frame.left;
        const right: usize = current_frame.right;
        const middle: usize = quick_sort_partition_hoare(buf, left, right);
        if (middle > left) {
            try stack.push(allocator, .{ .left = left, .right = middle, .state = .NO_RECURSE });
        }
        if (middle + 1 < right) {
            try stack.push(allocator, .{ .left = middle + 1, .right = right, .state = .NO_RECURSE });
        }
    }
}

fn max_in_arr(buf: anytype) @TypeOf(buf[0]) {
    var result: @TypeOf(buf[0]) = std.math.minInt(@TypeOf(buf[0]));
    for (0..buf.len) |i| {
        if (buf[i] > result) {
            result = buf[i];
        }
    }
    return result;
}
const SortError = error{
    NonIntegerError,
    InvalidDataTypeError
};

pub fn counting_sort(allocator: anytype, buf: anytype) !void {
    const T = @TypeOf(buf[0]);
    switch (@typeInfo(T)) { // Enforce unsigned data types for simplicity.
        .int => {
            switch (.signedness) {
                .signed => {
                    return SortError.InvalidDataTypeError;
                },
                else => {},
            }
        },
        else => {
            return SortError.NonIntegerError;
        },
    }
    const max = max_in_arr(buf);
    var sort_buf: []usize = try allocator.alloc(usize, @intCast(max + 1));
    defer allocator.free(sort_buf);
    @memset(sort_buf[0..], 0);
    for (0..buf.len) |i| {
        sort_buf[@as(usize, @intCast(buf[i]))] += 1;
    }
    var currentIndex: usize = 0; // Index for memsetting in the original buffer.
    for (0..sort_buf.len) |i| { // Loop through the counts buffer. i is the value being tested.
        const current_count = sort_buf[i]; // Frequency of the value i.
        @memset(buf[currentIndex..currentIndex+current_count], @as(T, @intCast(i)));
        currentIndex += current_count;
    }
}

pub fn print_arr(outstream: anytype, arr: anytype) !void {
    if (arr.len > 100) {
        try outstream.print("{{{d} Elements}}", .{arr.len});
        return;
    }
    try outstream.print("{{", .{});
    for (0..arr.len - 1) |i| {
        try outstream.print("{d}, ", .{arr[i]});
    }
    try outstream.print("{d}}}", .{arr[arr.len - 1]});
}

pub fn test_sorter(sorter_name: []const u8, allocator: anytype, sorter: anytype, outstream: anytype, buf: anytype) !SortResult {
    randomize(buf, 0, 100);
    try outstream.print("Testing {s}: ", .{sorter_name});
    try print_arr(outstream, buf);
    try outstream.print("\nResult: ", .{});
    for (0..sorter_name.len + 2) |_| { // Rectify spacing between prints.
        try outstream.print(" ", .{});
    }
    const start = std.time.nanoTimestamp();
    try sorter(allocator, buf);
    const end = std.time.nanoTimestamp();
    try print_arr(outstream, buf);
    const time = @as(f128, @floatFromInt(end - start)) / 1000000000.0;
    const result: SortResult = .{
        .time_seconds = time,
        .data_size = buf.len,
        .name = sorter_name,
        .efficiency = @as(f128, @floatFromInt(buf.len)) / time,
    };
    if (result.time_seconds < 1.0) {
        try outstream.print(" ({:.3}ms)\n", .{result.time_seconds * 1000});
    } else {
        try outstream.print(" ({:.3}s)\n", .{result.time_seconds});
    }
    try outstream.print("Is sorted: {}\n\n", .{is_sorted_ascending(buf)});
    try outstream.flush();
    reversed_identity(buf);
    return result;
}

pub inline fn is_sorted_ascending(buf: anytype) bool {
    for (1..buf.len) |i| {
        if (generic_comparator(buf[i], buf[i - 1], .LT)) {
            return false;
        }
    }
    return true;
}

pub inline fn is_sorted_descending(buf: anytype) bool {
    for (1..buf.len) |i| {
        if (generic_comparator(buf[i], buf[i - 1], .GT)) {
            return false;
        }
    }
    return true;
}
