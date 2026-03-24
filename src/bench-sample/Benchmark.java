import stdlib.StdRandom;
import stdlib.StdOut;
public class Benchmark {
    public static void print_arr(int [] arr) {
        if (arr.length > 100) {
            StdOut.print("{" + arr.length + " Elements}");
            return;
        }
        StdOut.print("{");
        for (int i=0; i<arr.length-1; i++) {
            StdOut.print(arr[i] + ", ");
        }
        StdOut.print(arr[arr.length - 1] + "}");
    }

    public static boolean is_sorted_ascending(int[] buf) {
        for (int i=1; i<buf.length; i++) {
            if (buf[i] < buf[i-1]) {
                return false;
            }
        }
        return true;
    }

    public static void insertion_sort(int[] buf, int min, int max) {
        if (min >= max) return;
        for (int i = min; i<max; i++) {
            int key = buf[i];
            var j = i;
            while (j > 0 && buf[j - 1] > key) {
                buf[j] = buf[j - 1];
                j -= 1;
            }
            buf[j] = key;
        }
    }
    
    public static int quick_sort_partition_hoare(int[] buf, int min, int max) {
        int i = min;
        int j = max;
        int pivot = buf[min];
        while (true) {
            while (i < max && buf[i] < pivot) {
                i += 1;
            }
            while (buf[j] > pivot) {
                j -= 1;
            }
            if (i >= j) {
                break;
            }
            int temp = buf[i];
            buf[i] = buf[j];
            buf[j] = temp;
            i += 1;
            j -= 1;
        }
        return j;
    }

    public static void quick_sort_recursive(int[] buf) {
        quick_sort_recursive_internal(buf, 0, buf.length - 1);
    }

    public static void quick_sort_recursive_internal(int[] buf, int min, int max) {
        if (max - min <= 16) {
            insertion_sort(buf, min, max + 1);
            return;
        }
        var min_side = min;
        while (min_side < max) {
            int new_pivot = quick_sort_partition_hoare(buf, min_side, max);
            quick_sort_recursive_internal(buf, min_side, new_pivot);
            min_side = new_pivot + 1;
        }
    }
    public static void main(String[] args) {
        int n = Integer.parseInt(args[0]);
        int[] arr = new int[n];
        for (int i=0; i<n; i++) {
            arr[i] = i;
        }
        for (int i=0; i<n; i++) {
            int rand = StdRandom.uniform(0, n);
            int temp = arr[i];
            arr[i] = arr[rand];
            arr[rand] = temp;
        }
        print_arr(arr);
        StdOut.println();
        long start = System.currentTimeMillis();
        quick_sort_recursive(arr);
        long result = System.currentTimeMillis() - start;
        print_arr(arr);
        StdOut.println();
        if (result > 1000) {
            StdOut.println("Time: " + (double)result / 1000 + "s");
        } else {
            StdOut.println("Time: " + result + "ms");
        }
        StdOut.println("Is sorted: " + is_sorted_ascending(arr));
    }
}