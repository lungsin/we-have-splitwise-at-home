#import "Basic";
#import "POSIX";
#import "Hash_Table";
#import "String";
#import "Random";
#import "Math";

#import,file "lib/avl.jai";

// This proc is copy-pasted from Jails since there isn't a cross-platform stdin processor yet from jai compiler
// https://github.com/SogoCZE/Jails/blob/dbfbed0068c416b7dcfcbbfdbc30fa90e3b347b4/server/rpc.jai#L3
read_from_stdin :: (buffer: *u8, bytes_to_read: u64) -> u64 {
    readed: u64;
    read_this_time: s64;

    #if OS == .WINDOWS {
        win32 :: #import "Windows";
        handle := win32.GetStdHandle(win32.STD_INPUT_HANDLE);
    } else {
        posix :: #import "POSIX";
    }

    while bytes_to_read > readed  {
        #if OS != .WINDOWS { // Linux, MacOS 
            read_this_time = posix.read(posix.STDIN_FILENO, buffer+readed, bytes_to_read-readed);
            if read_this_time < 0 {
              // probably EAGAIN or EINTR?
              err := posix.errno();
              if err != posix.EINTR && err != posix.EAGAIN {
                  log_error("Reading the stdin failed with errno: %", posix.errno());
                  return readed;
              } else {
                  // we should retry
              }
            } else if read_this_time == 0 {
              // probably closed (EOF)
              return readed;
            } else {
              readed += xx read_this_time;
            }
        } else { // Windows
            read_this_time = 0;
            ok := win32.ReadFile(handle, buffer+readed, xx (bytes_to_read-readed), xx *read_this_time);
            if ok && read_this_time == 0 return readed; // EOF
            readed += xx read_this_time;
        }
    }

    return readed;
}

read_line_from_stdin :: () -> string {
    sb : String_Builder;
    init_string_builder(*sb);
    char : u8;
    while read_from_stdin(*char, 1) {
        append(*sb, char);
        if char == #char "\n" {
            break;
        } 
    }
    return builder_to_string(*sb);
}

// A little utility function inspired by the string_to_int from "Basic" module
// This behaves like C++ istream on std::string
// It will take the first non-whitespace substring
string_to_non_space :: (t : string) -> result: string, success: bool, remainder: string {
    s := trim_left(t);
    if !s return "", false, "";

    i := find_index_of_any_from_left(s, DEFAULT_SPACES);
    if i == -1 return s, true, "";
    result := slice(s, 0, i);
    advance(*s, i);
    return result, true, s;
}

random_shuffle :: (arr : []$T) {
    for i: 1..arr.count - 1 {
        j := cast(s64)(random_get() % cast(u64)i);
        swap(*arr[i], *arr[j]);
    }
}

ignore_comment_in_string :: (s : string) -> string {
    idx := find_index_from_left(s, #char "#");
    if idx == -1 return s;
    return slice(s, 0, idx);
}

parse_input :: () -> (name_to_id : Table(string, int), names : [..]string, net : [..]s64) {
    name_to_id : Table(string, int);
    names : [..]string;
    net : [..]s64;

    register_name :: (name_ori : string) -> int #expand {
        name := copy_string(name_ori);
        found, id := table_find(*`name_to_id, name); 
        if found {
            return id; 
        }
        id_ptr := table_add(*`name_to_id, name, `name_to_id.count);
        id = id_ptr.*;
        array_add(*`names, name);
        array_add(*`net, 0);
        return id;
    }

    while line_loop := true {
        line := read_line_from_stdin();
        original_line := line;
        defer free(original_line);
        // check for EOF
        if line.count == 0 break;

        line = ignore_comment_in_string(line);

        froms : [..]int;
        froms.allocator = temp;

        froms_str : [..]string;
        froms_str.allocator = temp;
        defer reset_temporary_storage();

        // Parse lhs: space separated names representing who needs to pay for the bill
        while true {
            name:, success:, line = string_to_non_space(line);
            if !success continue line_loop;
            if name == "->"{
                if froms_str.count == 0 continue line_loop;
                break;
            }
            array_add(*froms_str, name);
        }
        // Parse rhs: payer name followed by the money amount
        name:, success:, line = string_to_non_space(line);
        if !success continue;
        to_str := name;

        // We use int for all the calculation to avoid weird floating error
        money_float:, success, line = string_to_float(line);
        if !success continue;
        money : int = cast(int)(money_float * 100);

        for froms_str {
            id := register_name(it);
            array_add(*froms, id);
        }
        to := register_name(to_str);

        // Distibute the money
        net[to] += money;
        random_shuffle(froms);
        for froms {
            net[it] -= money / froms.count;
            // distribute the remainder of the money randomly
            // hence the purpose of the random_shuffle above
            if it_index < money % froms.count {
                net[it] -= 1;
            }
        }
    }

    // A little validation on net: its sum must be zero
    net_sum := 0;
    for net net_sum += it; 
    assert(net_sum == 0, sprint("net_sum should be zero, actual: %\n", net_sum));

    return name_to_id, names, net;
}

Transaction :: struct {
    from, to : int;
    value : int;
}

// This is a greedy approximation algorithm that outputs a good-enough solution for the debt simplification problem.
// It's a 1.5-approximation, meaning the solution here is at most 1.5 times number of transactions compared to 
// the optimal solution (see [1] from the reference list below). There are additional "why not" heuristics I make here which 
// doesn't affect the analysis in the paper, but helps in practice.
// 
// References:
// - [1] Better Approximations for the Minimum Common Integer Partition Problem
//   https://www.cs.cmu.edu/afs/cs/user/dwoodruf/www/w06mcip.pdf
solve :: (net : []int) -> []Transaction {
    transactions : [..]Transaction;

    net_pos, net_neg : AVL_Tree(int, [..]int);

    check_and_remove_exact_match :: (val: int) #expand {
        ids_pos := avl_get(*`net_pos, val);
        ids_neg := avl_get(*`net_neg, val);

        if ids_pos == null || ids_neg == null return;
        match_num := min(ids_pos.count, ids_neg.count);
        for 1..match_num {
            id_pos := pop(ids_pos);
            id_neg := pop(ids_neg);
            array_add(*`transactions, {id_neg, id_pos, val});
        }
        if ids_pos.count == 0 avl_remove(*`net_pos, val);
        if ids_neg.count == 0 avl_remove(*`net_neg, val);
    }

    for net {
        if it == 0 continue;
        net_tree_ptr := ifx it < 0 then *net_neg else *net_pos;
        net_other_tree_ptr := ifx it < 0 then *net_pos else *net_neg;
        money := abs(it);

        // Insert to the avl
        ids_ptr := avl_get_or_init(net_tree_ptr, money);
        array_add(ids_ptr, it_index);
    }

    // Remove exact match
    for net {
        if it > 0 {
            check_and_remove_exact_match(it);
        }
    }

    // Main loop: match the two largest and check if the remainder have exact match
    while !avl_is_empty(*net_pos) {
        assert(!avl_is_empty(*net_neg), "Something is wrong: net_neg is empty when net_pos is not empty");
        
        node_pos := avl_find_largest(*net_pos);
        node_neg := avl_find_largest(*net_neg);

        money_pos := node_pos.key;
        money_neg := node_neg.key;

        money_transaction := min(money_pos, money_neg);
        money_remaining := abs(money_pos - money_neg);

        ids_pos := *node_pos.value;
        ids_neg := *node_neg.value;

        ids_remaining_ptr : *[..]int;
        if money_pos > money_neg {
            ids_remaining_ptr = avl_get_or_init(*net_pos, money_remaining);
        } else if money_pos < money_neg {
            ids_remaining_ptr = avl_get_or_init(*net_neg, money_remaining);
        }

        for 1..min(ids_pos.count, ids_neg.count) {
            id_pos := pop(ids_pos);
            id_neg := pop(ids_neg);
            array_add(*transactions, {id_neg, id_pos, money_transaction});
            if money_pos == money_neg continue;
            id_remaining := ifx money_pos > money_neg then id_pos else id_neg;
            array_add(ids_remaining_ptr, id_remaining);
        }

        if ids_pos.count == 0 avl_remove(*net_pos, money_pos);
        if ids_neg.count == 0 avl_remove(*net_neg, money_neg);

        check_and_remove_exact_match(money_remaining);
    }

    // a little validation logic
    net_result : [..]int;
    net_result.allocator = temp;
    array_resize(*net_result, net.count);
    for transactions {
        net_result[it.from] -= it.value;
        net_result[it.to] += it.value;
    } 
    for 0..net.count - 1 assert(net[it] == net_result[it]);
    return transactions;
}

print_transactions :: (transactions : []Transaction, names : []string) {
    max_lhs_length, max_rhs_length, max_val_length := 0;

    num_digits :: (n: int) -> int {
        result := 0;
        while n > 0 {
            n /= 10;
            result += 1;
        }
        return result;
    }

    for transaction : transactions {
        lhs := names[transaction.from];
        rhs := names[transaction.to];
        max_lhs_length = max(max_lhs_length, lhs.count);
        max_rhs_length = max(max_rhs_length, rhs.count);
        max_val_length = max(max_val_length, num_digits(transaction.value));
    }


    defer reset_temporary_storage();
    tindent_spaces :: (s: string, spaces: int, indent_at_start: bool = true) -> string {
        sb : String_Builder;
        sb.allocator = temp;
        init_string_builder(*sb, s.count + spaces);
        if !indent_at_start append(*sb, s);
        for 1..spaces append(*sb, " ");
        if indent_at_start append(*sb, s);
        return builder_to_string(*sb, do_reset=false);
    }

    for transaction : transactions {
        lhs := names[transaction.from];
        rhs := names[transaction.to];
        lhs = tindent_spaces(lhs, max_lhs_length - lhs.count, indent_at_start=true);
        rhs = tindent_spaces(rhs, max_rhs_length - rhs.count, indent_at_start=false);
        value := cast(float64) transaction.value / 100.0;
        print("% -> % : %\n", lhs, rhs, formatFloat(value, width=max_val_length + 1, trailing_width = 2, zero_removal = FormatFloat.Zero_Removal.NO));
    }
}

main :: () {
    cur_time := current_time_consensus();
    random_seed(cast,force(Some_Big_Time_Value)cur_time);
    name_to_id, names, net := parse_input();
    transactions := solve(net);
    print_transactions(transactions, names);
} 

