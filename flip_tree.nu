# Flip a binary tree horizontally
# Input: A tree with value, left, right fields
# Output: The flipped tree

def flip_tree [tree] {
  # Base case: empty tree
  if ($tree | is-empty) {
    return $null
  }

  # Create new node with same value
  let new_node = {
    value: $tree.value
    left: ($tree.right | flip_tree)
    right: ($tree.left | flip_tree)
  }

  # Return the new node
  return $new_node
}
