# -------------------------------------------------------------------------------------
# Filename:     ece3504_project1_colinedsall.asm
# Author:       Colin Edsall
# Date:         6 March 2025
# Version:      1.1
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
#               -> Note that return addresses are pushed and popped to the stack until
#                  the exit program call is made.
#
# Version History:
# 1:            First version sent to GitHub, uses limited stack allocation and focuses
#               on using registers to store variables between functions and subroutines.
# 1.1           Changes program to allow for stack allocation for return registers after
#               jumping and linking as well as handling exit of program/repeat in terms
#               of jumping back to the return address assigned from the kernel procedure.                    
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
    # STORE RETURN ADDRESS TO KERNEL IN STACK
    # Cannot use exit condition (syscall) to return to OS kernel - Dr Ransbottom
    # It's safer to always save the return address to the kernel
    # before we do a JAL to another function (i.e. process_buffer here)
    # Syscall exit is a halt, not a return to the kernel
    addi $sp, $sp, -4                                   # Allocate 4 bytes to stack for
                                                        # return address
    sw $ra, 0($sp)

    # Since we are adding to the stack several times in this program, it is important
    # to note that this is the FIRST addition to the stack as the return register
    # Thus, we know where to access it once we are done with program execution and can
    # return the to kernel text segment after coming back.

    # Here we must allocate some space on the stack for our buffer of chars:
    # Allocate space on the stack for our buffer (maximum of 100 characters)
    addi $sp, $sp, -100                                 # Allocate 100 bytes on stack

    # Print prompt
    li $v0, 4                                           
    la $a0, prompt
    syscall                                             # Reference the syscall table

    # Read user input
    li $v0, 8 
    move $a0, $sp                                       # This stores the contents input
                                                        # to the console in &($a0 = $sp)
    li $a1, 100                                         # Length of array
    syscall                                             # Reference the syscall table

    # Remove newline character inserted to the input 
    li $t0, 0                                           # Indexing temporary register

    move $a0, $sp                                       # Store stack pointer into $a0
                                                        # This is an argument for the
                                                        # function we call to.
    
    # Start jump to function process_buffer (note changes $ra)
    jal process_buffer                                  # To remove newline character and
                                                        # check if input == "QUIT"

    # Jumps to string_compare to check if input == "QUIT", now we return here
    beq $v0, 1, exit_program                            # If we return and output
                                                        # $v0 is TRUE (=1), then we must
                                                        # exit the program

    # If we need to exit the program, that will already be done. Now, we need to validate
    # the input to make sure it is an alpha string. Note that the return address here
    # is still stored in the stack to before we added the character string input, so
    # before we exit the program we'll have to manage that (in the exit_program function)

    # Now that we have made sure the input string isn't equal to "QUIT", we must validate
    # that it is only alpha characters. This calls to another function, of which has an
    # argument of passing the stack pointer (already declared above)
    move $a0, $sp                                       # Redundant check for $sp
    jal validate_input                                  # To make sure is alpha

    # Jumps to is_alpha to check if input is alphabetic or not, now we return here
    beq $v0, 0, invalid_input                           # If output $v0 is 0, then the
                                                        # input string is NOT alphabetic

    # If we need to restart the program, that will already be done. Now, we need to
    # go through the Pig Latin procedure to modify the array of chars that we put into
    # the stack. This can be done by calling to a function with a couple arguments.
    move $a0, $sp                                       # Redundant check for $sp
    jal process_input                                   # To process input string

    # Now that we're back, we want to restore the return address to the kernel procedure
    lw $ra, 0($sp)
    addi $sp, $sp, 4

    j main                                              # Restart program (NOT EXIT)


# -------------------------------------------------------------------------------------
# This function checks if the input string is equivalent to "QUIT", which requires the
# program to quit and go to the exit procedure.
# Its arguments are:
#   $a0 = stack pointer
# It modifies the following callee saves
#   $s0 = stack pointer (to be indexed)
#   $s1 = value of current character in stack (indexed value)
process_buffer:
    move $s0, $a0                                       # Callee save for address
                                                        # of array (input string)
process_buffer_loop:
    lb $s1, 0($s0)                                      # Move the first element of the
                                                        # stack to $s1 for processing
    beq $s1, 10, replace_null                           # Go to replace the null char
                                                        # IFF the current char = 10
                                                        # (newline) in ASCII
    addi $s0, $s0, 1                                    # Increment address of sp (temp)
    j process_buffer_loop                               # Keep looping (does not change $ra)

# Sub
replace_null:
    sb $zero, 0($s0)                                    # Store 0 (0-terminate) at end
                                                        # of array in stack.

# Now we continue to the check quit loop. This iterates through the array of chars
# to verify that the input string is valid or not to be processed

# Note that $s0 still contains the current stack pointer that we are accessing
# This segment of the code sets up the procedure that we use to validate the input
# string as only consisting of alpha characters, but first we need to check if we
# must quit the program.
# This subfunction's arguments are: n/a. We don't need any information from above
# and have to restart checking the string, so we should use the 
# So, we can use any callee saves as needed
check_quit:
    move $a0, $sp                                       # Reset $a0 to equal $sp
    la $a1, quit                                        # Store the quit label in $a1

    # This jumps to compare the string, of which we will get an output that we branch
    # on in the next line. 
    # Since we don't need to save these values for later, we don't have to add to the
    # stack. These values are parameters that we are going to pass into the next
    # function.

    # We still need to return the return address to here to allow for chaining
    # of jumps back to the main function
    addi $sp, $sp, -4                                   # Add 4 bytes to the stack
    sw $ra, 0($sp)                                       # Push return address to stack

    # Caller registers are now free, so we can call to the string_compare function

    jal string_compare                                  # Jump and store this as the $ra
    
    # After coming back here, the $ra is still to this point, so we need to restore that
    # here.
    lw $ra, 0($sp)                                      # Pop the return address back
    addi $sp, $sp, 4                                    # Restore stack memory

    # Now that we have processed the buffer and decided if we need to exit the program,
    # we can go back to the main function and proceed with other function calls.
    jr $ra                                              # Return to main function

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
# This function uses the following callee saves:
#   $s0:    Address of first string
#   $s1:    Address of second string
#   $s2:    Value of first string (indexed)
#   $s3:    Value of second string (indexed)
string_compare:
    li $v0, 1                                           # Assume strings are equal

    move $s0, $a0                                       # Callee save to $s0 for pointer
    move $s1, $a1                                       # Callee save to $s1 for pointer

    j compare_loop

compare_loop:
    lb $s2, 0($s0)                                      # Load char from first string
    lb $s3, 0($s1)                                      # Load char from second string
    
    bne $s2, $s3, not_equal                             # If mismatch, strings are not 
                                                        # equal
    beqz $s3, strings_equal                             # If we reach null terminator,
                                                        # they are equal
    addi $s0, $s0, 1                                    # Move to next character in first
                                                        # string
    addi $s1, $s1, 1                                    # Move to next character in second
                                                        # string
    j compare_loop                                      # Repeat loop

not_equal:
    li $v0, 0                                           # Set result to false (0)
strings_equal:
    jr $ra                                              # Return to check_quit
# -------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------
# Function: validate_input
# This function has the arguments:
#   $a0: contains stack pointer
# This function modifies callee saves
#
validate_input:
    # Note that we have $a0 as an argument in this function, so we don't need to save it
    # since we don't care about modifying it here. It will simply be passed onto the
    # subroutine is_alpha

    addi $sp, $sp, -4                                   # Allocate 4 bytes onto stack for $ra
    sw $ra, 0($sp)                                      # Store $ra on stack before JAL

    jal is_alpha                                        # Jump to check if the input string
                                                        # is alpha or not

    # Free up the stack for the return address
    lw $ra, 0($sp)                                      # Restore $ra
    addi $sp, $sp, 4                                    # Deallocate stack for $ra

    jr $ra                                              # Go back to main

# -------------------------------------------------------------------------------------
# Subfunction: is_alpha
# Checks if a string contains only alphabetic characters
# Arguments:
#   $a0 - Address of input string                       # Stored on stack ($sp)
# Returns:
#   $v0 = 1 if string is alphabetic, 0 otherwise        # Bool type function
# This function modifies the following callee saves
#   $s0:    Pointer to input string (stack, to be indexed)
#   $s1:    Value of character in input string (to be indexed)
#   $s2:    Pointer to consonants array
#   $s3:    Pointer to vowels array
#   $s4:    Current consonant/vowel from consonants/vowels array to compare
#
is_alpha:
    move $s0, $a0                                       # Pointer to input string (temp)
    j is_alpha_loop                                     # Jump to check loop

is_alpha_loop:
    lb $s1, 0($s0)                                      # Load char of input into $s1
    beqz $s1, alpha_valid                               # If null terminator, valid input

    # Check if character is alphabetic
    la $s2, consonants                                  # $s2 contains pointer to
                                                        # consonants array
    la $s3, vowels                                      # $s3 contains pointer to vowels
                                                        # array

alpha_match:
    lb $s4, 0($s2)                                      # $s4 contains current consonant
                                                        # to check from consonants array
    
    beqz $s4, vowel_match                               # If no match found in consonants,
                                                        # go to vowels (end of consonant
                                                        # string is branching condition)
    
    beq $s1, $s4, next_char                             # If equal, we go to the next input
                                                        # character
    addi $s2, $s2, 1                                    # Increment array pointer (+1 byte)
    j alpha_match                                       # Continue the loop

# In the case that no consonants match, we must check vowels
vowel_match:
    lb $s4, 0($s3)                                      # $s4 now contains current vowel
    beqz $s4, alpha_invalid                             # If no match found in vowels
                                                        # then the input string is NOT
                                                        # alphabetic
    beq $s1, $s4, next_char                             # Go to next input character
    addi $s3, $s3, 1                                    # Increment pointer by 1 byte
    j vowel_match                                       # Continue looping

next_char:
    addi $s0, $s0, 1                                    # Increment input array pointer
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
# Function: process_input
# This function processes the buffer of chars we inserted into the stack as is needed
# by the definition of Pig Latin. The input arguments are:
#   $a0:    Pointer to stack (start of array)
# The function calls to the subfunction: pig_latin_transform

process_input:
    # We need to print the buffer before we modify it, since it's much easier to just
    # modify the input string on the stack then store it originally somewhere else.
    # Note that $a0 already contains the address of the null-terminated string
    li $v0, 4
    syscall                                             # Reference syscall table

    # The lines above printed the current array of strings onto the stack, so now
    # we can pass that into the pig_latin_transform function, since $a0 was never
    # modified

    # After printing the original string, we can start processing it and determine
    # how to modify it. But, we should save the stack pointer here.

    addi $sp, $sp, -4                                   # Allocate 4 bytes to stack
    sw $ra, 0($sp)                                      # Store return address

    # Note that $a0 still contains the stack pointer, so we don't need to change
    # that argument before we go to the pig_latin_transform function.
    jal pig_latin_transform                             # Now we jump to transform

    
    # After returning from the processing subprogram we can start printing and go
    # back to the main function.

    lw $ra, 0($sp)                                      # Restore $ra
    addi $sp, $sp, 4                                    # Deallocate 4 bytes to stack

    # Handling printing output
    li $v0, 4                                           # Print output text
    la $a0, output1
    syscall

    li $v0, 4                                           # Print transformed string
    move $a0, $sp
    syscall

    li $v0, 4                                           # Print a newline
    la $a0, newline
    syscall

    # We must deallocate the stack before we can return and restart the program
    addi $sp, $sp, 100                                  # Deallocate 100 bytes
    jr $ra                                              # Return to main

    # After deallocating, we should expect that the only information on the stack
    # is the kernel return address.

# -------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------
# Function: pig_latin_transform
# Transforms input string into Pig Latin
# Arguments:
#   $a0 - Address of input string                       # Stored on stack ($sp)
# Returns:
#   
# This function modifies the following callee saves:
#   $s0:    Input string pointer
#   $s1:    First character to compare
#   $s2:    Second character (right after first) to compare
#   $s3:    Pointer to vowels array
#   $s4:    Current comparison value of vowels array
#
# This function calls to the two following subfunctions:
#   vowel_case
#       Arguments: 
#   consonants_case
#
pig_latin_transform:
    move $s0, $a0                                       # Input pointer stored in $s0
    lb $s1, 0($s0)                                      # Store first char in $s1
    lb $s2, 1($s0)                                      # Store second char $s2
 
    # Check if first char is a vowel
    # This is generally quicker if we assume that the fastest
    # way to an output is that the input word starts with a vowel
    la $s3, vowels                                      # Load $s3 with vowels array ptr
    j vowel_check                                       # Jump to vowel_check

# Checks the FIRST character, not second (this is a for loop)
vowel_check:
    lb $s4, 0($s3)                                      # Load $t4 with current vowel to
                                                        # check
    
    beqz $s4, consonant_case_preparation                # Go to consonants if we are
                                                        # at the end of the vowel check
                                                        # string

    # $a0 contains the buffer pointer, keep passing it
    beq $s1, $s4, vowel_case                            # Go to the vowel case if the
                                                        # first character is a vowel

    addi $s3, $s3, 1                                    # Increment vowel array ptr
    j vowel_check                                       # Keep looping

consonant_case_preparation:
    # In the case where the first character is not a vowel, we need to set up for the
    # consonant case, of which two of the arguments are the first and second consonants
    # in the string. For readability, we store them here in $a1 and $a2, since $a0 contains
    # the buffer pointer that we are passing on

    move $a1, $s1                                       # Store first char in $a1
    move $a2, $s2                                       # Store second char in $a2

    # We need to save the index of the input array in $t0 as a caller save
    move $t0, $a0                                       # Store input array pointer
    move $t1, $a0                                       # Store stack pointer
    j consonant_case


# -------------------------------------------------------------------------------------
# Subfunction: vowel_case
# Called to when the first letter of the input string is a vowel
# This function has the following arguments:
#   n/a
# This function stores the pointer to the data segment containing the suffix "way"
# and calls to the subroutine to append the suffix.
vowel_case:
    # Note that $a0 already contains the buffer location, so no modification
    # needed here.
    la $a1, suffix_way                                  # Put ptr to "way" in $a0
    # Pass argument of the suffix to $a1
    j append_suffix                                     # Go to append_suffix
    
    # Do not need to come back as this happens at the end

# -------------------------------------------------------------------------------------
# Subfunction: consonant_case
# Called to when the first letter is NOT a vowel
# This function has the following arguments:
#   $a0:    Pointer to the input string (unmodified from original function)
#   $a1:    Value of first character in string
#   $a2:    Value of second character in string
# This function has the following caller saves:
#   $t0:    Pointer to index array (to be indexed later)
#   $t1:    Pointer to current stack location (to be indexed later)
#   $t2:    Value of consonant to insert at end (modified if there are two)
# This function modifies the following callee saves:
#   $s0:    Number of arrays of consonant pairs that we are checking
#   $s1:    Clusters array(s) pointer
#   $s2:    Pointer to data segment for "ay" suffix   
#   $s3:    Pointer to current clusters array we are checking
#   $s6:    Used for move operations (i.e. shifting array right)
#   $s4:    Current clusters array value we grabbed (first of two, since clusters are size 2)
#   $s5:    Current clusters array value grabbed (second of two, since clusters ~ SH, sh, etc.)
#   $s7:    Contains the flag to repeat the procedure for checking clusters
#
# Note that there are several subroutines and loops called to in this subfunction,
# which either represent indexed for() loops or other procedures that are branched on
# conditionals. The main callee saves/caller saves for each label are identified if they
# differ from this header.
#
consonant_case:
    # We need to add behavior to check if the first two consonants
    # are in the list above.

    # Predefine a value that holds the number of arrays of clusters to
    # go through. Right now it is:  4 (+1 for indexing)
    li $s0, 5                                           # We want to check all clusters
                                                        # of consonants so we decrement
                                                        # this number until we reach 0

    la $t2, suffix_ay                                   # Put ptr to "ay" into $t2

    j cluster_array_indexing                            # Jump to array indexing

cluster_array_indexing:
    # Ideally, we don't have to do any error catching since there MUST
    # be a value in these lists that matches the consonants, else we only have 1
    # And that case is already handled. Add more to the arrays if we need more pairs

    # Use $s0 as a counter variable (such that the highest numbered temp register is
    # separate from the other registers holding data)
    addi $s0, -1                                        # Decrement the number of arrays
                                                        # left
    
    beq $s0, 4, load_cluster                            # Conditionals to choose which
    beq $s0, 3, load_cluster1                           # array to check.
    beq $s0, 2, load_cluster2
    beq $s0, 1, load_cluster3                           # See data segment of memory.

# We must add new functions to check for other arrays if we add more clustered consonants
load_cluster:
    la  $s1, clusters
    j cluster_check                                     # Check this cluster

load_cluster1:
    la  $s1, clusters1
    j cluster_check                                     # Check this cluster

load_cluster2:
    la  $s1, clusters2
    j cluster_check                                     # Check this cluster

load_cluster3:
    la  $s1, clusters3
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
    lb $s4, 0($s1)                                      # Load the first cluster to
                                                        # check in $s4
    beqz $s4, cluster_array_indexing                    # Go to next array if
                                                        # we don't find a match for this
    beqz $s0, single_cons_case                          # If we are at the end of the 
                                                        # arrays we can go back and check 
                                                        # just for one consonant

    # Load the second value of the cluster
    lb $s5, 1($s1)                                      # Load second value of cluster
                                                        # to check (indexed by 2's)
    
    # Note that if the next value in the array is zero (or unallocated, the)
    # condition above will avoid this and a memory access error, so we don't
    # have to worry about this.

    # Now we need to check if ($a1 == $s4 && $a2 == $s5)
    beq $a1, $s4, check_second_cons                     # If the first pair is a match,
                                                        # go further

    # Else, check next cluster and repeat
    addi $s1, $s1, 2                                    # Index by 2, since the array
                                                        # above has groups of size 2
    j cluster_check                                     # Loop

check_second_cons:
    bne $a2, $s5, second_cons_failed                    # If the second pair does not
                                                        # match, go to handling other 
                                                        # consonants

    # Else, we follow a procedure similar to if we have 1 consonant
    # We can instead make two calls to move the consonant,
    # For example: If the first two letters are ShXXXX, we must first move
    # the first letter to the end, then the second. This can be done
    # by holding a flag control in append_consonant, of which we define

    # If the flag is 1, then we must repeat the move to the end.
    # If the flag is 0, then we only move one consonant to the end (i.e. single_cons_case)

    li $s7, 1                                           # $s7 holds the flag for repeat
    addi $t0, $t0, 1                                    # Offset index of input array by 1
    
    move $t3, $a1                                       # Store first consonant in $t3

    j move_to_end                                       # Jump to move over chars

second_cons_failed:
    # In the case that the second consonant isn't exactly what we want
    # i.e. we have Bc (invalid) and not Bl (valid), we need to still increment the index 
    # and return.
    addi $s1, $s1, 2                                    # Offset index by 2
    j cluster_check                                     # Go back to check other clusters

second_cons_repeat:
    # Note that $a0 contains the pointer to the start of the input string
    # We need to swap the values of $t2 and $t1 to repeat operation
    move $t3, $a2                                       # Load second value to append
    li $s7, 0                                           # Don't come back to here
                                                        # (repeat flag = 0)

    move $t0, $a0                                       # Reset pointer stored in $t0->$sp
    move $t1, $a0                                       # Reset pointer stored in $t1->$sp
                                                        # (left indexed of array)

    addi $t0, $t0, 1                                    # Increment pointer to next
                                                        # part of array.


    j move_to_end                                       # Go to move the character in $t3
                                                        # to end of array.

single_cons_case:
    addi $t0, $t0, 1                                    # Move past first consonant (left)
                                                        # in stack

    # Suffix is already assigned
    li $s7, 0                                           # Assign the flag to repeat in $s7
                                                        # as 0             

    move $t3, $a1                                       # Use $t3 to hold the first consonant
    j move_to_end                                       # Got to append character at end

move_to_end:
    # This subroutine processes the following caller saves:
    #   $t0:    Current input array index (to be modified)
    #   $t1:    Stack pointer of array index (to be used to modify stack)
    #   $t3:    The first consonant in the string
    j copy_rest
    # Note that, as this function is called to, we currently have temporary pointers to
    # the current location of the stack pointer ($t1) and the next index ($t0)

# This subfunction works by moving the entire string left (removing first character)
copy_rest:
    lb $s6, 0($t0)                                      # Load what's to left to $s6
    sb $s6, 0($t1)                                      # Store what's in $s6 to the right
    
    beqz $s6, append_consonant                          # Store the starting consonant(s)
                                                        # IF we've reached the end
    
    addi $t0, $t0, 1                                    # Increment pointer to array + 1
    addi $t1, $t1, 1                                    # Increment pointer to array
    
    j copy_rest                                         # Loop

append_consonant:
    sb $t3, 0($t1)                                      # Move first consonant to end
    addi $t1, $t1, 1                                    # Increment pointer to array
    sb $zero, 0($t1)                                    # Store 0 at incremented pointer
                                                        # (NULL) terminated

    bnez $s7, second_cons_repeat                        # Repeat this procedure depending
                                                        # on flag value (if NOT 0, repeat)

    move $a1, $t2                                       # Restore pointer to suffix array

    j append_suffix                                     # Go to append_suffix
# -------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------
# Now the flag for checking for clusters is useless, so we can use that
# The flag for the indexing of the clusters arrays is also useless, so we can use that too
# Subroutine: append_suffix
# This function has the following arguments:
#   $a0:    Buffer pointer (to input string)
#   $a1:    Pointer to suffix data segment (i.e. "way" or "ay")
# This function modifies the following callee saves to be clobbered by the caller later
#   $s0:    Address of the input string array
#   $s1:    Address of suffix string array
#   $s2:    Value of the input string array at an index
#   $s3:    Value of the suffix array at an index
append_suffix:
    move $s0, $a0                                       # Load the address of the array
    move $s1, $a1
find_end:
    lb $s2, 0($s0)                                      # Load the value of the buffer
                                                        # at an index
    beqz $s2, add_suffix                                # If we found the end index in $s1,
                                                        # branch
    
    addi $s0, $s0, 1                                    # Increase index till we find 0
    j find_end                                          # Loop

    # Keep the buffer address we want in $s0 for now (end of it to append)

add_suffix:
    lb $s3, 0($s1)                                      # Load the suffix starting value
                                                        # to $s3 
    j append_loop                                       # jump to append the loop

append_loop:
    sb $s3, 0($s0)                                      # From above, $s0 contains the 
                                                        # address of the starting point
                                                        # of the suffix array
    addi $s0, $s0, 1                                    # Increment the end of the buffer 
                                                        # position pointer
    addi $s1, $s1, 1                                    # Increment the array indexing for 
                                                        # the suffix.

    lb $s3, 0($s1)                                      # Grab new value of suffix
    bnez $s3, append_loop                               # If we aren't at the end of the 
                                                        # suffix, loop

    sb $zero, 0($s0)                                    # Eventually, null-terminate buffer

    # For output, we need to store the pointer that we are working on into $v0

    jr $ra                                              # Return

# -------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------
# Only called to if we want to exit the program and return to the kernel procedure
# This means that we have to clear the stack and its contents, of which this label
# knows that there exists an array of 100 bytes on the stack AND the return address
# of the kernel procedure in the stack as well (104 bytes), so, all we have to do
# is remove the 100 bytes and store the return address, then jump... after printing
# the exit dialogue.
exit_program:
    li $v0, 4
    la $a0, quit_msg
    syscall

    # Restore the 100 bytes we allocated to the stack for the buffer
    addi $sp, $sp, 100

    lw $ra, 0($sp)                                      # Return to the kernel procedure
    jr $ra                                              # Jump back

    # Note that we DON'T CARE what the value of $ra is, since that is going to be 
    # gobbled in the kernel procedure.

    # Syscall exit is not supported at this point in the programming knowledge we have
    # li $v0, 10
    # syscall
# -------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------
# Only called to if the string input is not alphabetic. This restarts the program, but
# we must reallocate the stack back to its default. Note that This means clearing the
# entire stack, aka removing the buffer of chars and then the return address to kernel
# since it will be reassigned back in main
invalid_input:
    li $v0, 4
    la $a0, error_msg
    syscall

    # Restore the 104 bytes we allocated to the stack for the buffer and return register
    addi $sp, $sp, 104

    jr $ra                                              # Return to main