
AVL_Node :: struct($K: Type, $V: Type) {
    key : K;
    left, right : *AVL_Node(K, V);
    height : int;
    value : V;
}

AVL_Tree :: struct($K: Type, $V: Type) {
    root : *AVL_Node(K, V);
    count : int;
}

// Node utility
new_avl_node :: (key: $K, value: $V) -> *AVL_Node(K, V) {
    new_node := New(AVL_Node(K, V));
    new_node.key = key;
    new_node.value = value;
    new_node.height = 1;
    return new_node;
}

avl_get_node_height :: (node : *AVL_Node($K, $V)) -> int {
    if node == null {
        return 0;
    }
    return node.height;
}

// Tree read-only procedure
avl_is_empty :: (tree : *AVL_Tree($K, $V)) -> bool {
    return tree == null || tree.root == null;
}

avl_get :: (tree : *AVL_Tree($K, $V), key: K) -> *V {
    node := avl_find(tree, key);
    if node == null return null;
    return *(node.value);
}

avl_find :: (tree : *AVL_Tree($K, $V), key: K) -> *AVL_Node(K, V) {
    cursor := tree.root;
    while true {
        if cursor == null || cursor.key == key return cursor;
        if key < cursor.key cursor = cursor.left;
        else cursor = cursor.right;
    }
    // Unreachable
    assert(false, "Unreachable code: something is wrong");
    return null;
}

avl_get_largest :: (tree : *AVL_Tree($K, $V)) -> *V {
    node := avl_find_largest(tree);
    if node == null return null;
    return *node.value;
}

avl_find_largest :: (tree : *AVL_Tree($K, $V)) -> *AVL_Node(K, V) {
    cursor := tree.root;
    if cursor == null return null;
    while cursor.right != null cursor = cursor.right;
    return cursor;
}

avl_print :: (tree : *AVL_Tree($K, $V)) {
    dfs :: (node : *AVL_Node($K, $V), depth := 0) {
        if node == null return;
        dfs(node.left, depth + 1);
        dfs(node.right, depth + 1);
        for 1..depth print("  ");
        print("% = %\n", node.key, node.value);
    }
    print("%\n", tree.root);
    dfs(tree.root);
    print("\n");
}

// Tree with side effect procedure

avl_find_or_init :: (tree : *AVL_Tree($K, $V), key : K) -> node: *AVL_Node(K, V), is_new: bool {
    default_value : V;
    new_root, node, is_new := _avl_insert_if_not_exist_recursive(tree.root, key, default_value);
    tree.root = new_root;
    return node, is_new;
}

avl_get_or_init :: (tree : *AVL_Tree($K, $V), key : K) -> value_ptr: *V, is_new: bool {
    node, is_new := avl_find_or_init(tree, key);
    return *node.value, is_new;
}

avl_insert_or_replace :: (tree : *AVL_Tree($K, $V), key: K, value: V) {
    tree.root = _avl_insert_or_replace_recursive(tree.root, key, value);
}


avl_remove :: (tree : *AVL_Tree($K, $V), key: K, cleanup: bool = true) -> (removed_node : *AVL_Node(K, V)) {
    new_root, removed_node := _avl_remove_recursive(tree.root, key);
    tree.root = new_root;
    if cleanup {
        free(removed_node);
        return null;
    }
    removed_node.left = null;
    removed_node.right = null;
    return removed_node;
}

avl_free :: (tree : *AVL_Tree($K, $V)) {
    dfs_free :: (node : *AVL_Node(K, V)) {
        if node == null return;
        dfs_free(node.left);
        dfs_free(node.right);
        free(node);
    }
    dfs_free(tree.root);
    tree.root = null;
}

// Internal methods

// fix node.height assuming the children's height is already fixed
_avl_fix_height :: (node : *AVL_Node($K, $V)) {
    node.height = max(avl_get_node_height(node.left), avl_get_node_height(node.right)) + 1;
}

// rotate right if the node is imbalanced to the left
_avl_maybe_rotate_right :: (node : *AVL_Node($K, $V)) -> *AVL_Node(K, V) {
    if avl_get_node_height(node.right) + 1 >=  avl_get_node_height(node.left) {
        _avl_fix_height(node);
        return node;
    }
    left := node.left;
    node.left = left.right;
    left.right = node;
    _avl_fix_height(node);
    _avl_fix_height(left);
    return left;
}

_avl_maybe_rotate_left :: (node : *AVL_Node($K, $V)) -> *AVL_Node(K, V) {
    if avl_get_node_height(node.left) + 1 >=  avl_get_node_height(node.right) {
        _avl_fix_height(node);
        return node;
    }
    right := node.right;
    node.right = right.left;
    right.left = node;
    _avl_fix_height(node);
    _avl_fix_height(right);
    return right;
}

_avl_insert_if_not_exist_recursive :: (root : *AVL_Node($K, $V), key: K, value: V) -> new_root: *AVL_Node(K, V), node: *AVL_Node(K, V), is_new: bool {
    if root == null {
        new_node := new_avl_node(key, value);
        return new_node, new_node, true;
    }

    if root.key == key {
        return root, root, false;
    } else if root.key < key {
        new_root_right, node, is_new := _avl_insert_if_not_exist_recursive(root.right, key, value);
        if is_new {
            // only rotate if new node is inserted
            root.right = new_root_right;
            root = _avl_maybe_rotate_left(root);
        }
        return root, node, is_new;
    } else {
        new_root_left, node, is_new := _avl_insert_if_not_exist_recursive(root.left, key, value);
        if is_new {
            // only rotate if new node is inserted
            root.left = new_root_left;
            root = _avl_maybe_rotate_right(root);
        }
        return root, node, is_new;
    }
    // unreachable
    assert(false);
    return null, null, false;
}


_avl_insert_or_replace_recursive :: (root : *AVL_Node($K, $V), key: K, value: V) -> *AVL_Node(K, V) {
    if root == null {
        return new_avl_node(key, value);
    }

    if root.key == key {
        root.value = value;
    } else if root.key < key {
        root.right = _avl_insert_or_replace_recursive(root.right, key, value);
        root = _avl_maybe_rotate_left(root);
    } else {
        root.left = _avl_insert_or_replace_recursive(root.left, key, value);
        root = _avl_maybe_rotate_right(root);
    }
    return root;
}

_avl_remove_recursive :: (root : *AVL_Node($K, $V), key: K) -> (new_root : *AVL_Node(K, V), removed_node: *AVL_Node(K, V)) {
    if root == null {
        return null, null;
    }

    if root.key == key {
        if root.right == null {
            return root.left, root;
        }
        // Find a replacement for the current root node
        new_right, replacement_node := _avl_remove_recursive_leftmost(root.right);
        root.right = new_right;
        // Replace the current root with the replacement node
        // There are two ways to do this: swap the node values, or swap the children.
        // As an optimization, we do the former if the size of value is small, and the latter otherwise.
        #if size_of(V) <= 8 {
            swap(*root.value, *replacement.value);
            root = _avl_maybe_rotate_right(root);
            return root, replacement;
        } else {
            replacement_node.left = root.left;
            replacement_node.right = root.right;
            replacement_node = _avl_maybe_rotate_right(replacement_node);
            return replacement_node, root;
        }
    }

    removed_node : *AVL_Node(K, V);
    if root.key < key {
        root.right, removed_node = _avl_remove_recursive(root.right, key);
        root = _avl_maybe_rotate_right(root);
    } else {
        root.left, removed_node = _avl_remove_recursive(root.left, key);
        root = _avl_maybe_rotate_left(root);
    }
    return root, removed_node;
}

_avl_remove_recursive_leftmost :: (root : *AVL_Node($K, $V)) -> (new_root : *AVL_Node(K, V), removed_node: *AVL_Node(K, V)) {
    if root.left == null {
        return root.right, root;
    }
    removed_node : *AVL_Node(K, V);
    root.left, removed_node = _avl_remove_recursive_leftmost(root.left);
    root = _avl_maybe_rotate_left(root);
    return root, removed_node;
}

#import "Basic";
