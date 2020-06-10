do_state_tasks <- function(oldest_active_sites, ...) {

  # Define task table rows
  task_names <- oldest_active_sites$state_cd

  # Define task table columns
  download_step <- create_task_step(
    step_name = 'download',
    target_name = function(task_name, ...) sprintf('%s_data', task_name),
    command = function(task_name, ...) {
      sprintf("get_site_data(oldest_active_sites, I('%s'), parameter)", task_name)
    }
  )

  # Create the task plan
  task_plan <- create_task_plan(
    task_names = task_names,
    task_steps = list(download_step),
    add_complete = FALSE)

  # Create the task remakefile
  create_task_makefile(
    task_plan = task_plan,
    makefile = '123_state_tasks.yml',
    include = 'remake.yml',
    sources = '1_fetch/src/get_site_data.R',
    packages = c('tidyverse','dataRetrieval'),
    tickquote_combinee_objects = FALSE,
    finalize_funs = c())

  # Build the tasks
  scmake('123_state_tasks', remake_file='123_state_tasks.yml')

  # Return nothing to the parent remake file
  return()
}
