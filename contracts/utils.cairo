%lang starknet

from contracts.events import Check

func emit_arr{syscall_ptr: felt*, range_check_ptr}(arr_len: felt, arr: felt*) {
    if (arr_len == 0) {
        return ();
    }
    Check.emit(value=[arr]);
    return emit_arr(arr_len - 1, arr + 1);
}
