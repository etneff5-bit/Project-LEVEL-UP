//run through Termux with Termux:API
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void ding();
void notify(const char *msg);
int BJJTimer();
int MMATimer();
int CardioTimer();

int main(int argc, char *argv[]){
    if(argc < 2){
        printf("Usage: %s <timer_type>\n", argv[0]);
        return 1;
    }

    system("termux-wake-lock");
    
    notify("Workout Timer Started");

    if(strcmp(argv[1], "BJJ") == 0){
        BJJTimer();
    } else if(strcmp(argv[1], "MMA") == 0){
        MMATimer();
    } else if(strcmp(argv[1], "Cardio") == 0){
        CardioTimer();
    } else{
        notify("Timer Type Not Accepted");
    }

    system("termux-wake-unlock");
    return 0;
}

void notify(const char *msg) {
    printf("%s\n", msg);
    char command[256];
    snprintf(command, sizeof(command), "termux-notification --id 99 --title 'Workout Active' --content '%s'", msg);
    system(command);
}

int BJJTimer(){
  notify("Follow the routine:\nBurpees, Bear crawl, Mountain climbers, sprawls, shadow grappling, rest\nRepeat 5 times.");
  sleep(5);
  ding();
    
  for(int i = 0; i < 5; i++){
      notify("Action: Burpees!"); 
      sleep(60);
      ding();
        
      notify("Action: Bear Crawl!");
      sleep(60);
      ding();
        
      notify("Action: Mountain Climbers!");
      sleep(60);
      ding();
        
      notify("Action: Sprawls!");
      sleep(60);
      ding();
        
      notify("Action: Shadow Grappling!");
      sleep(60);
      ding();
        
      sleep(1);
      ding();
        
      notify("Status: Rest Period");
      sleep(60);
      ding();
    }
    sleep(1);
    ding();
    sleep(1);
    ding();
    notify("Workout Finished!");
    return 0;
}

int MMATimer(){
    notify("Routine: Sprint 30s, Jog 30s.\nRepeat 5 times, then rest 1 min.");
    sleep(5);
ding();
    
    for(int i = 0; i < 5; i++){
        for(int j = 0; j < 5; j++){
            notify("Action: SPRINT!");
            sleep(30);
            ding();
            notify("Action: Jog");
            sleep(30);
            ding();
        }
        notify("Status: Rest (1 Minute)");
        sleep(60);
        ding();
    }
    notify("Workout Finished!");
    sleep(1);
    ding();
    return 0;
}

int CardioTimer(){
    notify("Routine: Run for 30 minutes!");
    sleep(5);
    ding();
    
    sleep(900);
    notify("Status: Halfway there! (15 mins left)");
    ding();
    
    sleep(900);
    notify("Workout Finished!");
    ding();
    sleep(1);
    ding();
    return 0;
}

void ding(){
    system("termux-vibrate -d 600");
    system("termux-media-player play ~/storage/shared/Download/bell.mp3");
}
