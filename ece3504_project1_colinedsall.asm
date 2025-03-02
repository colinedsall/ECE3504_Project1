# -------------------------------------------------------------------------------------
# Filename:     ece3504_project1_colinedsall.asm
# Author:       Colin Edsall
# Date:         6 March 2025
# Version:      1
# Description:  This code satisfies the functional requirements for the Pig Latin
#               project described in this project specification. It properly
#               handles prompting the user for an input string and modifying that
#               string on the stack such that the Pig Latin version of any valid
#               string of letters (alphabetic character only) is then output to
#               the console for viewing.
#               This program also handles common repeated consonants of any case, in
#               which they should be moved to the end as a group instead of the first
#               consonant only.
#
#               The expected behavior (simplified) is:
#               ->  if first letter is a vowel
#                   ->  append "way" to end, done.
#               ->  if first letter is a consonant or a pair of consonants
#                   ->  append "ay" to end after moving first consonant(s) to end
#               
#               The stack allocation is as follows:
#               -> Allocate 100 bytes of information on stack for a maximum of 100 char
#                  input array.
#               -> Stack contains the input string and its modified output, all changes
#                  are stored on the stack to optimize usage.
#               -> Several temporary and argument registers are used to hold the current
#                  character value.
#                   
# -------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------
# Data Segment (Should NOT be modified)
.data
    # Prompts and messages, formatting
    prompt:      .asciiz "Enter an alphabetic character string (QUIT to exit): "
    output1:     .asciiz " translates to: "
    newline:     .asciiz "\n"
    quit_msg:    .asciiz "Thank You! QUIT translates to: UITQay. Good Bye!\n"
    error_msg:   .asciiz "Invalid input! Please enter an alphabetic string.\n"

    # All possible vowels and consonants (of any case)
    vowels:      .asciiz "AEIOUaeiou"
    consonants:  .asciiz "bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ"

    # Clusters of repeated consonants to check (to allow Share -> areShay)
    clusters:    .asciiz "blBlBLbrBrBRclClCLdrDrDRflFlFLfrFrFRglGl"
    clusters1:   .asciiz "GLgrGrGRplPlPLprPrPRscScSCskSkSKslSlSL"
    clusters2:   .asciiz "shShSHchChCHthThTHphPhPHwhWhWHsmSmSMsnSn"
    clusters3:   .asciiz "SNspSpSPstStSTswSwSWtwTwTWcrCrCR"

    # Suffixes
    suffix_ay:   .asciiz "ay"
    suffix_way:  .asciiz "way"

    # Quit
    quit:        .asciiz "QUIT"
# -------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------
# Text Segment
.text
.globl main

# Begin main function call
main:
    # Allocate space on the stack for our buffer
    addi $sp, $sp, -100                                 # Allocate 100 bytes on stack
    move $s0, $sp                                       # Creates a pointer to the stack

    # Print prompt
    li $v0, 4                                           
    la $a0, prompt
    syscall                                             # Reference the syscall table

    # Read user input
    li $v0, 8 
    move $a0, $s0                                       # This stores the contents input
                                                        # to the console in &($a0 = $sp)
    li $a1, 100                                         # Length of array
    syscall                                             # Reference the syscall table

    # Remove newline character inserted to the input 
    li $t0, 0                                           # Indexing temporary register
    move $a0, $s0                                       # Store stack pointer into $a0
    
    # Start jump to all subprocesses
    jal process_buffer                                  # To remove newline character

# This function checks if the input string is equivalent to "QUIT", which requires the
# program to quit and go to the exit procedure.
# Its arguments are $a0 = stack pointer
process_buffer:
    move $t0, $a0                                       # Temporary save for address
                                                        # of array (input string)
process_buffer_loop:

    lb $t1, 0($t0)                                      # Move the first element of the
                                                        # stack to $t1 for processing
    beqz $t1, check_quit                                # If $t1 = 0, check quitting
    beq $t1, 10, replace_null                           # Go to replace the null char
                                                        # IFF the current char = 10
                                                        # (newline) in ASCII
    addi $t0, $t0, 1                                    # Increment address of sp (temp)
    j process_buffer_loop                               # Keep looping

replace_null:
    sb $zero, 0($t0)                                    # Store 0 (0-terminate) at end
                                                        # of array.

# Note that $a0 still contains the current stack pointer that we are accessing
# This segment of the code sets up the procedure that we use to validate the input
# string as only consisting of alpha characters, but first we need to check if we
# must quit the program.
check_quit:
    move $a0, $s0                                       # Reset $a0 to equal $sp = $s0
    la $a1, quit                                        # Store the quit label in $a1
    jal string_compare                                  # Jump and store this as the $ra
    
    # Jumps to string_compare to check if input == "QUIT", now we return here
    beq $v0, 1, exit_program                            # If we return and output
                                                        # $v0 is TRUE (=1), then we must
                                                        # exit the program

validate_input:
    move $a0, $s0                                       # Restore stack pointer into $a0
    jal is_alpha                                        # Jump to check if the input string
                                                        # is alpha or not

    # Jumps to is_alpha to check if input is alphabetic or not, now we return here
    beq $v0, 0, invalid_input                           # If output $v0 is 0, then the
                                                        # input string is NOT alphabetic

    # Else: continue to process the input

# Since we know that the input string is valid, we can continue to process it
# and modify it on the stack.
process_input:
    move $a0, $s0                                       # Restore stack pointer
                                                        # into $a0
    # We need to print the buffer before we modify it, since it's much easier to just
    # modify the input string on the stack then store it originally somewhere else.
    li $v0, 4
    # move $a0, $s0                                     # Store $a0 with stack pointer
    syscall                                             # Reference syscall table

    # After printing the original string, we can start processing it and determine
    # how to modify it.

    # Note that $a0 still contains the stack pointer, so we don't need to change
    # that argument before we go to the pig_latin_transform function.
    jal pig_latin_transform                             # Now we jump to transform
    # After returning from the processing subprogram we can start printing and go
    # back to the main function.

    li $v0, 4                                           # Print output text
    la $a0, output1
    syscall

    li $v0, 4                                           # Print transformed string
    move $a0, $s0
    syscall

    li $v0, 4                                           # Print a newline
    la $a0, newline
    syscall

    # We must deallocate the stack before we can return and restart the program
    addi $sp, $sp, 100                                  # Deallocate 100 bytes
    j main                                              # Return to main

invalid_input:
    li $v0, 4
    la $a0, error_msg
    syscall
    j main

exit_program:
    li $v0, 4
    la $a0, quit_msg
    syscall
    li $v0, 10
    syscall
# -------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------
# Function: string_compare
# Compares two strings character by character
# Arguments:
#   $a0 - Address of first string                       # Pointer to string array
#   $a1 - Address of second string                      # Pointer to QUIT string
# Returns:
#   $v0 = 1 if strings are equal                        # This is a bool function
#   $v0 = 0 if strings are different
# We have the address of the data segment for "QUIT" to check if we need to quit.
# This is the ONLY string that we are comparing, since we assume that there are
# no other conditions we have to validate the string for.
string_compare:
    li $v0, 1                                           # Assume strings are equal

compare_loop:
    lb $t0, 0($a0)                                      # Load char from first string
    lb $t1, 0($a1)                                      # Load char from second string
    bne $t0, $t1, not_equal                             # If mismatch, strings are not 
                                                        # equal
    beqz $t0, strings_equal                             # If we reach null terminator,
                                                        # they are equal
    addi $a0, $a0, 1                                    # Move to next character in first
                                                        # string
    addi $a1, $a1, 1                                    # Move to next character in second
                                                        # string
    j compare_loop                                      # Repeat loop

not_equal:
    li $v0, 0                                           # Set result to false (0)
strings_equal:
    jr $ra                                              # Return to check_input
# -------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------
# Function: is_alpha
# Checks if a string contains only alphabetic characters
# Arguments:
#   $a0 - Address of input string                       # Stored on stack ($sp)
# Returns:
#   $v0 = 1 if string is alphabetic, 0 otherwise        # Bool type function
is_alpha:
    move $t0, $a0                                       # Pointer to input string (temp)

is_alpha_loop:
    lb $t1, 0($t0)                                      # Load char of input into $t1
    beqz $t1, alpha_valid                               # If null terminator, valid input

    # Check if character is alphabetic
    la $t2, consonants                                  # $t2 contains pointer to
                                                        # consonants array
    la $t3, vowels                                      # $t3 contains pointer to vowels
                                                        # array

alpha_match:
    lb $t4, 0($t2)                                      # $t4 contains current consonant
                                                        # to check from consonants array
    
    beqz $t4, vowel_match                               # If no match found in consonants,
                                                        # go to vowels (end of consonant
                                                        # string is branching condition)
    
    beq $t1, $t4, next_char                             # If equal, we go to the next input
                                                        # character
    addi $t2, $t2, 1                                    # Increment array pointer (+1 byte)
    j alpha_match                                       # Continue the loop

# In the case that no consonants match, we must check vowels
vowel_match:
    lb $t4, 0($t3)                                      # $t4 now contains current vowel
    beqz $t4, alpha_invalid                             # If no match found in vowels
                                                        # then the input string is NOT
                                                        # alphabetic
    beq $t1, $t4, next_char                             # Go to next input character
    addi $t3, $t3, 1                                    # Increment pointer by 1 byte
    j vowel_match                                       # Continue looping

next_char:
    addi $t0, $t0, 1                                    # Increment input array pointer
                                                        # by one byte
    j is_alpha_loop                                     # Keep looping all checks

# Process if the input is valid or not
alpha_invalid:
    li $v0, 0                                           # Invalid input -> output = 0
                                                        # (FALSE)
    jr $ra                                              # Return to caller

alpha_valid:
    li $v0, 1                                           # Valid input -> output = 1
                                                        # (TRUE)
    jr $ra                                              # Return to caller
# -------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------
# Function: pig_latin_transform
# Transforms input string into Pig Latin
# Arguments:
#   $a0 - Address of input string                       # Stored on stack ($sp)
# Returns:
#   nothing                                             # Void type function
pig_latin_transform:
    move $t0, $a0                                       # Input pointer stored in $t0
    lb $t1, 0($t0)                                      # Store first char in $t1
    lb $t2, 1($t0)                                      # Store second char $t2
 
    # Check if first char is a vowel
    # This is generally quicker if we assume that the fastest
    # way to an output is that the input word starts with a vowel
    la $t3, vowels                                      # Load $t3 with vowels array ptr

vowel_check:    # Checks the FIRST character, not second
    lb $t4, 0($t3)                                      # Load $t4 with current vowel to
                                                        # check
    
    beqz $t4, consonant_case                            # Go to consonants if we are
                                                        # at the end of the vowel check
                                                        # string

    beq $t1, $t4, vowel_case                            # Go to the vowel case if the
                                                        # first character is a vowel

    addi $t3, $t3, 1                                    # Increment vowel array ptr
    j vowel_check                                       # Keep looping

vowel_case:
    # la $a0, buffer                                    # Arg: buffer address
    la $t5, suffix_way                                  # Put ptr to "way" in $t5
    j append_suffix                                     # Go to append_suffix
    # Do not need to come back as this happens at the end

consonant_case:
    # We need to add behavior to check if the first two consonants
    # are in the list above.
    # Note that $t1 and $t2 contain the first and second input chars, respectively

    # Predefine a value that holds the number of arrays of clusters to
    # go through. Right now it is:              4
    li $t9, 5                                           # We want to check all clusters
                                                        # of consonants so we decrement
                                                        # this number until we reach 0

    la $t3, clusters                                    # Load the clusters ptr to $t3
    la $t5, suffix_ay                                   # Put ptr to "ay" into $t5

cluster_array_indexing:
    # Ideally, we don't have to do any error catching since there MUST
    # be a value in these lists that matches the consonants, else we only have 1
    # And that case is already handled. Add more to the arrays if we need more pairs

    # Use $t9 as a counter variable (such that the highest numbered temp register is
    # separate from the other registers holding data)
    addi $t9, -1                                        # Decrement the number of arrays
                                                        # left
    
    # We load the cluster array indexing to $t3
    beq $t9, 4, load_cluster                            # Conditionals to choose which
    beq $t9, 3, load_cluster1                           # array to check.
    beq $t9, 2, load_cluster2
    beq $t9, 1, load_cluster3                           # See data segment of memory.

# We must add new functions to check for other arrays if we add more clustered consonants
load_cluster:
    la  $t3, clusters
    j cluster_check                                     # Check this cluster

load_cluster1:
    la  $t3, clusters1
    j cluster_check                                     # Check this cluster

load_cluster2:
    la  $t3, clusters2
    j cluster_check                                     # Check this cluster

load_cluster3:
    la  $t3, clusters3
    j cluster_check                                     # Check this cluster

# Here we begin a loop to check for clusters
# The way we can do this is by loading a value from the cluster
# array and then compare the value of the first consonant. If the 
# first consonant is a match to itself in the array, we compare the next
# indexed cluster and see if that matches. If all passes, then
# we have a special function to append these values to the end as needed

# Since there is a limitation on how many characters we can have per
# label, we need to go through all of them
cluster_check:
    lb $t4, 0($t3)                                      # Load the first cluster to
                                                        # check in $t4
    beqz $t4, cluster_array_indexing                    # Go to next array if
                                                        # we don't find a match for this
    beqz $t9, single_cons_case                          # If we are at the end of the 
                                                        # arrays we can go back and check 
                                                        # just for one consonant

    # Load the second value of the cluster
    lb $t6, 1($t3)                                      # Load second value of cluster
                                                        # to check (indexed by 2's)
    
    # Note that if the next value in the array is zero (or unallocated, the)
    # condition above will avoid this and a memory access error, so we don't
    # have to worry about this.

    # Now we need to check if ($t1 == $t4 && $t2 == $t6)
    beq $t1, $t4, check_second_cons                     # If the first pair is a match,
                                                        # go further

    # Else, check next cluster and repeat
    addi $t3, $t3, 2                                    # Index by 2, since the array
                                                        # above has groups of size 2
    j cluster_check                                     # Loop

check_second_cons:
    bne $t2, $t6, second_cons_failed                    # If the second pair does not
                                                        # match, go to handling other 
                                                        # consonants

    # Else, we follow a procedure similar to if we have 1 consonant
    # We can instead make two calls to move the consonant,
    # For example: If the first two letters are ShXXXX, we must first move
    # the first letter to the end, then the second. This can be done
    # by holding a flag control in append_consonant, of which we define

    # If the flag is 1, then we must repeat the move to the end.
    # If the flag is 0, then we only move one consonant to the end (i.e. single_cons_case)

    li $t8, 1                                           # $t8 holds the flag for repeat
    addi $t0, $t0, 1                                    # Offset index of input array by 1
    j move_to_end                                       # Jump to move over chars

second_cons_failed:
    # In the case that the second consonant isn't exactly what we want
    # i.e. we have Bc (invalid) and not Bl (valid), we need to still increment the index 
    # and return.
    addi $t3, $t3, 2                                    # Offset index by 2
    j cluster_check                                     # Go back to check other clusters

second_cons_repeat:
    # Note that $t0 contains the ptr to the start of the input string
    # We need to swap the values of $t2 and $t1 to repeat operation
    move $t1, $t2                                       # Load second value to append
    li $t8, 0                                           # Don't come back to here
                                                        # (repeat flag = 0)

    move $t0, $a0                                       # Reset pointer stored in $t0->$sp
    addi $t0, $t0, 1                                    # Increment pointer to next (empty)
                                                        # part of array.
    j move_to_end                                       # Go to move the character in $t1
                                                        # to end of array.

single_cons_case:
    addi $t0, $t0, 1                                    # Move past first consonant (left)
                                                        # in stack

    # Suffix is already assigned
    li $t8, 0                                           # Assign the flag to repeat in $t8
                                                        # as 0                
    j move_to_end                                       # Got o append character at end

move_to_end:
    move $t7, $s0                                       # Store current stack pointer
                                                        # in $t7

    # Note that, as this function is called to, we currently have temporary pointers to
    # the current location of the stack pointer ($t7) and the next index ($t0)

# Note that $t6 is no longer useful since we've already used that flag to check
# if we have a grouped consonant.
# This subfunction works by moving the entire string left (removing first character)
copy_rest:
    lb $t6, 0($t0)                                      # Load what's to left to $t6
    sb $t6, 0($t7)                                      # Store what's in $t6 to the right
    
    beqz $t6, append_consonant                          # Store the starting consonant(s)
                                                        # IF we've reached the end
    
    addi $t0, $t0, 1                                    # Increment pointer to array + 1
    addi $t7, $t7, 1                                    # Increment pointer to array
    j copy_rest                                         # Loop

append_consonant:
    sb $t1, 0($t7)                                      # Move first consonant to end
    addi $t7, $t7, 1                                    # Increment pointer to array
    sb $zero, 0($t7)                                    # Store 0 at incremented pointer
                                                        # (NULL) terminated

    bnez $t8, second_cons_repeat                        # Repeat this procedure depending
                                                        # on flag value (if NOT 0, repeat)

# Now the flag for checking for clusters is useless, so we can use that
# The flag for the indexing of the clusters arrays is also useless, so we can use that too
append_suffix:
    move $t3, $s0                                       # Load the address of the array
find_end:
    lb $t9, 0($t3)                                      # Load the value of the buffer
                                                        # at an index
    beqz $t9, add_suffix                                # if we found the end index in $t9,
                                                        # branch
    
    addi $t3, $t3, 1                                    # Increase index till we find 0
    j find_end                                          # Loop

    # Keep the buffer address we want in $t8 for now (end of it to append)

add_suffix:
    lb $t6, 0($t5)                                      # Load the suffix starting value
                                                        # to $t6   
append_loop:
    sb $t6, 0($t3)                                      # From above, $t5 contains the 
                                                        # address of the starting point
                                                        # of the suffix array
    addi $t3, $t3, 1                                    # Increment the end of the buffer 
                                                        # position pointer
    addi $t5, $t5, 1                                    # Increment the array indexing for 
                                                        # the suffix.

    lb $t6, 0($t5)                                      # Grab new value of suffix
    bnez $t6, append_loop                               # If we aren't at the end of the 
                                                        # suffix, loop

    sb $zero, 0($t3)                                    # Eventually, null-terminate buffer
    jr $ra                                              # Return to main

