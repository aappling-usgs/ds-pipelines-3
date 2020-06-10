do_state_tasks <- function(oldest_active_sites, ...) {

  # Split the inventory by state
  split_inventory('1_fetch/tmp/state_splits.yml', sites_info=oldest_active_sites)

  # Define task table rows
  task_names <- oldest_active_sites$state_cd

  # Define task table columns
  download_step <- create_task_step(
    step_name = 'download',
    target_name = function(task_name, ...) sprintf('%s_data', task_name),
    command = function(task_name, ...) {
      sprintf("get_site_data('1_fetch/tmp/inventory_%s.tsv', parameter)", task_name)
    }
  )
  plot_step <- create_task_step(
    step_name = 'plot',
    target_name = function(task_name, ...) sprintf('3_visualize/out/timeseries_%s.png', task_name),
    command = function(task_name, steps, ...) {
      # sprintf("plot_site_data(out_file=target_name, site_data=%s_data, parameter=parameter)", task_name)
      # OR
      sprintf("plot_site_data(out_file=target_name, site_data=%s, parameter=parameter)", steps$download$target_name)
    }
  )
  tally_step <- create_task_step(
    step_name = 'tally',
    target_name = function(task_name, ...) sprintf('%s_tally', task_name),
    command = function(task_name, steps, ...) {
      # sprintf("tally_site_obs(site_data=%s_data)", task_name)
      # OR
      sprintf("tally_site_obs(site_data=%s)", steps$download$target_name)
    }
  )

  # Create the task plan
  task_plan <- create_task_plan(
    task_names = task_names,
    task_steps = list(download_step, plot_step, tally_step),
    add_complete = FALSE)

  # Create the task remakefile
  create_task_makefile(
    task_plan = task_plan,
    makefile = '123_state_tasks.yml',
    include = 'remake.yml',
    sources = c(...),
    packages = c('tidyverse','dataRetrieval','lubridate'),
    tickquote_combinee_objects = FALSE,
    finalize_funs = c())

  # Build the tasks
  scmake('123_state_tasks', remake_file='123_state_tasks.yml')

  # Return nothing to the parent remake file
  return()
}

split_inventory <- function(
  summary_file='1_fetch/tmp/state_splits.yml',
  sites_info=oldest_active_sites) {

  if(!dir.exists('1_fetch/tmp')) dir.create('1_fetch/tmp')

  out_files <- sapply(seq_len(nrow(sites_info)), function(r) {
    site_info <- sites_info[r,]
    out_file <- sprintf('1_fetch/tmp/inventory_%s.tsv', site_info$state_cd)
    readr::write_tsv(site_info, out_file)
    return(out_file)
  })

  scipiper::sc_indicate(summary_file, data_file=sort(out_files))
}
