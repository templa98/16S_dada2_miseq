__version__ = '1.0.0'
import os 
import json
import subprocess
import time
import math


def colorize(text, color):
    xterm_colors = {
        "black": 0,
        "red": 1,
        "green": 2,
        "yellow": 3,
        "blue": 4,
        "magenta": 5,
        "cyan": 6,
        "white": 7,
        "bright_black": 8,
        "bright_red": 9,
        "bright_green": 10,
        "bright_yellow": 11,
        "bright_blue": 12,
        "bright_magenta": 13,
        "bright_cyan": 14,
        "bright_white": 15
    }
    color_code = xterm_colors.get(color.lower(), 7)
    reset = "\033[0m"
    return f"\033[38;5;{color_code}m{text}{reset}"
def red(text):
    return colorize(text, 'red')
def green(text):
    return colorize(text, 'green')
def yellow(text):
    return colorize(text, 'yellow')
def blue(text):
    return colorize(text, 'blue')
def white(text):
    return colorize(text, 'white')
def bold(text):
    # ANSI escape code for bold
    bold = "\033[1m"
    
    # Reset bold
    reset = "\033[0m"
    
    # Return the bold text
    return f"{bold}{text}{reset}"
def tab(num_tab = 1):
    return f'  '*num_tab
def bubu():
    return green('Bubu')
def clear_terminal():
    if os.name == 'nt':
        # Windows
        os.system('cls')
    else:
        # Unix/Linux/Mac
        os.system('clear')
def push_page(page: str):
    navigation.append(green(page))
def pop_page():
    if len(navigation) > 1:
        return navigation.pop()
    return None
def push_message(message:str):
    messages.append(message)
def push_loading_screen():
    clear_terminal()
    print(f'Hang on! {bold(bubu())} is working ...')
def pop_loading_screen():
    clear_terminal()


navigation = [bold(green("Bubu"))]
messages = []

def process_envrionment_variables():
    envs = os.environ
    args = dict()
    args['program_path'] = envs['PWD']
    args['is_compute_canada'] = True # TODO: Change this to False
    args['cluster'] = "cedar" # TODO: remove this line 
    if('CC_CLUSTER' in envs):
        args['is_compute_canada'] = True
        args['cluster'] = "cedar" # TODO: Change this to envs['CC_CLUSTER']
    
    return args   
def show_help():
    pass
def show_menu():
    print(f"{tab()}{bold(yellow('1. '))}{'Current runing jobs'}")
    print(f"{tab()}{bold(yellow('2. '))}{'Submit a job'}")
    print(f"{tab()}{bold(yellow('3. '))}{'Need more help?'}")
    print(f"{tab()}{red('4. Exit')}")
    print("\n")


def show_welcome(args):
    if args['is_compute_canada']:
        print(f"Welcome to {bold(bubu())} on {'Compute Canada'}({args['cluster']} node)\n\n")
    else:
        print(f"Welcome to {bubu()}")

def show_messages():
    if len(messages) > 0:
        # print(f'\n{bold(bubu())} says:')
        message_count = 1
        for message in messages:
            print(f'{bubu()}: {message}')
            message_count = message_count + 1
        messages.clear()

def show_navigation_path():
    transition = blue(" ≫ ")
    nav_str = transition.join(navigation)
    print(nav_str)
    print(yellow("-" * 80))

def page_current_jobs():
    job_ids = []
    slurm_jobs = None

    def get_user_slurm_jobs():
        push_loading_screen()
        command = 'squeue -u $(whoami) --noheader --format="%A;%u;%T;%M;%L;%D;%m;%C"'
        # result = subprocess.run(command, stdout=subprocess.PIPE, shell=True, text=True).stdout
        result = "32760913;trmshk;RUNNING;42:55;4:17:05;1;64G;12\n32760912;trmshk;PD;42:55;4:17;1;64G;12"
        #time.sleep(1)
        job_ids.clear()
        lines = result.strip().splitlines() 
        jobs = [line.split(';') for line in lines]
        for job in jobs:
            job_ids.append(job[0])
        pop_loading_screen()
        return jobs
        
        
    def show_slurm_job_table(jobs):
        headers = ["JobID", "User", "State", "TimeUsed", "TimeLeft", "Nodes", "Memory", "CPUs"]
        
        # calculate column widths
        column_widths = [len(header) for header in headers]
        for job in jobs:
            for i, column in enumerate(job):
                column_widths[i] = max(column_widths[i], len(column))
        
        # print headers
        header_row = " | ".join(f"{header:<{column_widths[i]}}" for i, header in enumerate(headers))
        print(header_row)
        print("-" * len(header_row))
        
        # print rows
        for job in jobs:
            row = " | ".join(f"{column:<{column_widths[i]}}" for i, column in enumerate(job))
            print(row)

    def show_current_jobs_menu():
        print()
        print(f"{tab()}{red('1. Go Back')}")
        print(f"{tab()}{bold(yellow('2. '))}{'Refresh jobs list'}")
        print(f"{tab()}{bold(yellow('3. '))}{'Cancel a job'}")
        print("\n")

    def show_cancel_menu():
        print()
        print(f"{tab()}{red('1. Go Back')}")
        print("\n")

    def cancel_slurm_job(job_id: str):
        if not job_id:
            push_message(red("Job ID is empty or not valid!"))
            return False
        if job_id not in job_ids:
            push_message(red("Job ID does not exist!"))
            return False


        command = f'scancel {job_id}'
        push_loading_screen()
        result = subprocess.run(command.strip(), shell=True, text=True)
        pop_loading_screen()

        if result.returncode == 0:
            return True
        else:
            return False

    def page_cancel_job():
        while True:
            slurm_jobs = get_user_slurm_jobs()
            clear_terminal()
            show_navigation_path()
            show_slurm_job_table(slurm_jobs)
            show_cancel_menu()
            show_messages()
            user_input = input(f'Please enter a job ID to cancel: ')
            if user_input == "1":
                break
            
            # cancel the job
            cancelled = cancel_slurm_job(user_input)

            if cancelled:
                push_message(green(f'Job {user_input} cancelled successfully'))
            else:
                push_message(red(f"Couldn't cancel job ID {user_input}"))
            




    while True:
        slurm_jobs = get_user_slurm_jobs()
        clear_terminal()
        show_navigation_path()
        show_slurm_job_table(slurm_jobs)
        show_current_jobs_menu()
        show_messages()
        user_input = input(f'Select one of the menu numbers for {bubu()}: ')
        if user_input == "1":
            break
        elif user_input == "2":
            continue
        elif user_input == "3":
            push_page("Cancel a job")
            page_cancel_job()
            pop_page()
        else:
            push_message(red("Wrong input! Please select one of the above numbers."))


def page_new_job():
    #TODO: implement this

    cc_job_res = {
        "cpu" : None,
        "mem" : None,
        "time.h": None,
        "time.m": None,
        "email": None
    }
    current_step = 0
    steps = [
        {"res": "cpu",     "title": "CPU Cores",    "message": f"Enter the numebr of {green(bold('CPU'))} cores",                       "default": 4,       "min": 1,       "max": 64       },
        {"res": "mem",     "title": "RAM Memory",   "message": f"Enter the amount of {green(bold('RAM'))} in GB",                       "default": 32,      "min": 4,       "max": 1024     },
        {"res": "time.h",  "title": "Hours",        "message": f"Enter the numebr of {green(bold('Hours'))} needed for the job",        "default": 2,       "min": 0,       "max": math.inf },
        {"res": "time.m",  "title": "Minutes",      "message": f"Enter the numebr of {green(bold('Minutes'))} needed for the job",      "default": 4,       "min": 0,       "max": 59       },
        {"res": "email",   "title": "Email",        "message": f"Enter an {green(bold('Email Address'))} to send notifications",        "default": None,    "min": None,    "max": None     }
    ]

    def process_and_update_step(step_counter):
        if(step_counter == len(steps)):
            return -1
        step = steps[step_counter]
        user_prompt = step["message"]
        if step["default"] != None:
            default = yellow(f'default is {step["default"]}')
            user_prompt = f'{user_prompt} ({default}): '
        else:
            default = yellow('leave empty to ignore')
            user_prompt = f'{user_prompt} ({default}): '
        
        show_messages()
        user_input = input(user_prompt)
        user_input = int(user_input, base=10)
        if (step["min"] != None) and (step["max"] != None): 
            if user_input > step["max"] or user_input < step["min"]:
                #FIXME: finish this part
                user_message = red(f'Invalid input. Value must follow ≤ ≤')
                push_message


    def show_completed_steps():
        pass

    while True:
        clear_terminal()
        show_navigation_path()
        print(f'Enter {red("Q")} at any step to go back to the main menu')
        print(f'Enter {yellow("Z")} to go to previous step')
        show_completed_steps(current_step)
        current_step = process_and_update_step(current_step)
        if current_step != -1:
            # continue if there are some steps remaining
            continue

        break

def page_help():
    #TODO: implement this
    while True:
        clear_terminal()
        show_navigation_path()
        print(f'For more help, visit {blue("https://bubu.com/docs")}\n\n')
        user_input = input(f'Press any key to go back !!! ')
        break


def app_loop(args):
    while True:
        clear_terminal()
        show_navigation_path()
        show_welcome(args)
        show_menu()
        show_messages()
        user_input = input(f'Select one of the menu numbers: ')
        if user_input == "4":
            break
        elif user_input == "1":
            push_page("Running Jobs")
            page_current_jobs()
            pop_page()
        elif user_input == "2":
            push_page("New Job")
            page_new_job()
            pop_page()
        elif user_input == "3":
            push_page("Help")
            page_help()
            pop_page()
        else:
            push_message(red("Wrong input! Please select one of the above numbers."))
        


def main():
    args = process_envrionment_variables()
    app_loop(args)
    clear_terminal()




if __name__ == '__main__':
    main()