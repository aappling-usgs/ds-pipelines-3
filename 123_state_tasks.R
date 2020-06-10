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
    final_steps = c('tally', 'plot'),
    add_complete = FALSE)

  # Create the task remakefile
  create_task_makefile(
    task_plan = task_plan,
    makefile = '123_state_tasks.yml',
    include = 'remake.yml',
    sources = c(...),
    packages = c('tidyverse','dataRetrieval','lubridate'),
    as_promises = TRUE,
    tickquote_combinee_objects = TRUE,
    final_targets = c('obs_tallies', '3_visualize/out/timeseries_plots.yml'),
    finalize_funs = c('combine_obs_tallies', 'summarize_timeseries_plots'))

  # Build the tasks
  loop_tasks(task_plan, '123_state_tasks.yml', num_tries=40, n_cores=1)
  obs_tallies <- remake::fetch('obs_tallies_promise', remake_file='123_state_tasks.yml')
  timeseries_plots_info <- yaml::yaml.load_file('3_visualize/out/timeseries_plots.yml') %>%
    tibble::enframe(name = 'filename', value = 'hash') %>%
    mutate(hash = purrr::map_chr(hash, `[[`, 1))

  # Return the combiner targets to the parent remake file
  return(list(obs_tallies=obs_tallies, timeseries_plots_info=timeseries_plots_info))
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

combine_obs_tallies <- function(...) {
  # filter to just those arguments that are tibbles (because the only step
  # outputs that are tibbles are the tallies)
  dots <- list(...)
  tally_dots <- dots[purrr::map_lgl(dots, is_tibble)]
  bind_rows(tally_dots)
}

summarize_timeseries_plots <- function(ind_file, ...) {
  # filter to just those arguments that are character strings (because the only
  # step outputs that are characters are the plot filenames)
  dots <- list(...)
  plot_dots <- dots[purrr::map_lgl(dots, is.character)]
  do.call(combine_to_ind, c(list(ind_file), plot_dots))
}
