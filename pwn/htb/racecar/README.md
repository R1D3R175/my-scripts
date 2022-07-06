# Introduction
The exploit in this challenge is a **Format String**, the flag is read via `fgets` to a variable not dynamically allocated hence we can leak it via `%x`. 

# Vulnerable Function
```c
void car_menu(void)

{
  int car_choice;
  int race_choice;
  uint curr_time;
  size_t waiting_length;
  char *your_input_formatstring;
  FILE *flag_txt_file;
  int canarino;
  int opponent_var1;
  int my_var1;
  uint char_iterator;
  // FLAG IS WRITTEN HERE
  char flag_buffer [44];
  int checker_canarino;
  
  checker_canarino = *(int *)(canarino + 0x14);
  do {
    printf(&select_car_1_2);
    car_choice = read_int();
    if ((car_choice != 2) && (car_choice != 1)) {
      printf("\n%s[-] Invalid choice!%s\n","\x1b[1;31m","\x1b[1;36m");
    }
  } while ((car_choice != 2) && (car_choice != 1));
  race_choice = race_type();
  curr_time = time((time_t *)0x0);
  srand(curr_time);
  if (((car_choice == 1) && (race_choice == 2)) || ((car_choice == 2 && (race_choice == 2)))) {
    opponent_var1 = rand();
    opponent_var1 = opponent_var1 % 10;
    my_var1 = rand();
    my_var1 = my_var1 % 100;
  }
  else if (((car_choice == 1) && (race_choice == 1)) || ((car_choice == 2 && (race_choice == 1)))) {
    opponent_var1 = rand();
    opponent_var1 = opponent_var1 % 100;
    my_var1 = rand();
    my_var1 = my_var1 % 10;
  }
  else {
    opponent_var1 = rand();
    opponent_var1 = opponent_var1 % 100;
    my_var1 = rand();
    my_var1 = my_var1 % 100;
  }
  char_iterator = 0;
  while( true ) {
    waiting_length = strlen("\n[*] Waiting for the race to finish...");
    if (waiting_length <= char_iterator) break;
    putchar((int)"\n[*] Waiting for the race to finish..."[char_iterator]);
    if ("\n[*] Waiting for the race to finish..."[char_iterator] == '.') {
      sleep(0);
    }
    char_iterator = char_iterator + 1;
  }
  if (((car_choice == 1) && (opponent_var1 < my_var1)) ||
     ((car_choice == 2 && (my_var1 < opponent_var1)))) {
    printf("%s\n\n[+] You won the race!! You get 100 coins!\n","\x1b[1;32m");
    coins = coins + 100;
    printf("[+] Current coins: [%d]%s\n",coins,"\x1b[1;36m");
    printf("\n[!] Do you have anything to say to the press after your big victory?\n> %s","\x1b[0m")
    ;
    your_input_formatstring = (char *)malloc(369);
    flag_txt_file = fopen("flag.txt","r");
    if (flag_txt_file == (FILE *)0x0) {
      printf("%s[-] Could not open flag.txt. Please contact the creator.\n","\x1b[1;31m");
                    /* WARNING: Subroutine does not return */
      exit(0x69);
    }
    
    // FGETS THAT LOADS THE FLAG INTO THE STACK
    fgets(flag_buffer,44,flag_txt_file);
    read(STDIN_FILENO,your_input_formatstring,368);
    puts(
        "\n\x1b[3mThe Man, the Myth, the Legend! The grand winner of the race wants the whole world  to know this: \x1b[0m"
        );
        
    // VULN IS HERE 
    printf(your_input_formatstring);
    // VULN IS HERE 
  }
  else if (((car_choice == 1) && (my_var1 < opponent_var1)) ||
          ((car_choice == 2 && (opponent_var1 < my_var1)))) {
    printf("%s\n\n[-] You lost the race and all your coins!\n","\x1b[1;31m");
    coins = 0;
    printf("[+] Current coins: [%d]%s\n",0,"\x1b[1;36m");
  }
  if (checker_canarino != *(int *)(canarino + 0x14)) {
    __stack_chk_fail_local();
  }
  return;
}
```
