#' Generate the text to put in a rd.rmd file to build a package function reference
#'
#' @param code_path path to the source code directory of the package
#' @param rd_index path to yaml file with index layout information
#' @param exclude vector of Rd entry names to exclude from the resulting document
#' @importFrom magrittr set_names
#' @importFrom tools Rd_db
#' @importFrom whisker whisker.render
#' @importFrom yaml yaml.load_file
#' @import stringr
#' @export
rd_template <- function(code_path, rd_index = "rd_index.yaml", exclude = NULL) {

  rd_info <- as_sd_package(code_path)

  # This should be done in init
    # # Under what conditions do we add `package_name` to exclude?
    # # Only of there doesn't exist a function or alias with the same name as the package
    # if (!(package_name %in% nms)){
    #   exclude <- unique(c(exclude, package_name))
    # }
    #
    # if (!is.null(exclude)){
    #   message("ignoring: ", paste(exclude, collapse = ", "))
    # }
    # nms <- setdiff(nms, exclude)

  rd_index_file <- rd_index
  rd_index <- try(yaml.load_file(rd_index) %>% as_rd_index(), silent = TRUE)
  if (inherits(rd_index, "try-error")) {
    stop("There was an error reading ", file.path(getwd(), rd_index_file), ":\n",
      geterrmessage())
  }

  check_rd_index(rd_index = rd_index, rd_info = rd_info)

  display_current_rd_index(rd_index)

  # allow for null values as they will not be displayed
  dat <- list(
    title = rd_info$title,
    version = rd_info$version,
    description = rd_info$description,
    license = rd_info$license,
    depends = rd_info$depends,
    imports = rd_info$imports,
    suggests = rd_info$suggests,
    enhances = rd_info$enhances,
    author = rd_info$authors
  )

  main_templ <- paste(readLines(file.path(system.file(package = "packagedocs"),
    "rd_template", "rd_main_template.Rmd")), collapse = "\n")
  rd_templ <- paste(readLines(file.path(system.file(package = "packagedocs"),
    "rd_template", "rd_template.Rmd")), collapse = "\n")

  for (ii in rev(seq_along(rd_index))) {
    alias_info_list <- rd_index[[ii]]$topics
    alias_info_list %>%
      lapply(function(topic_info) {
        try(get_rd_data(
          topic_info,
          rd_info
        ))
      }) ->
    entries

    idx <- which(
      as.logical(unlist(
        sapply(entries, function(x) inherits(x, "try-error"))
      ))
    )

    if (length(idx) > 0) {

      error_topics <- alias_files_from_topics(alias_info_list)[idx]
      entries <- entries[-idx]
      message(
        "there were errors running the following topics (will be removed): ",
        paste(error_topics, collapse = ", ")
      )
      rd_index <- remove_topics_from_index(rd_index, names(error_topics))
    }

    if (length(idx) < length(alias_info_list)) {
      # not all files were errors.  therefore the section still exists
      rd_index[[ii]]$entries <- unname(entries)
    }
  }


  tmp <- entries[[paste(rd_info$package, "-package", sep = "")]]
  if (!is.null(tmp)) {
    dat$description <- tmp$description
  }

  main <- whisker.render(main_templ, dat)
  all_entries <- whisker.render(rd_templ, rd_index)

  package_load <- paste("
  ```{r packagedocs_load_library, echo=FALSE}
  suppressWarnings(suppressMessages(
    library(", rd_info$package, ",
      quietly = TRUE, warn.conflicts = FALSE, verbose = FALSE
    )
  ))
  ```
  ", sep = "")

  res <- paste(c(main, package_load, all_entries), collapse = "\n")
  gsub("<code>\n", "<code>", res)
}

valid_id <- function(x) {
   # x <- gsub(" ", "-", x)
   # tolower(gsub("[^0-9a-zA-Z\\-]+", "", x))
  x <- gsub("\\.Rd", "", x)
  x
}

# to avoid gsubfn
fix_hrefs <- function(x) {
  tmp <- strsplit(x, "'")
  unlist(lapply(tmp, function(a) {
    idx <- which(grepl("\\.html$", a))
    a[idx] <- paste0("#", tolower(gsub("\\.html", "", a[idx])))
    paste(a, collapse = "")
  }))
}

get_rd_data <- function(
  topic_info, rd_info
) {
  alias_file <- topic_info$file

  # use staticdocs package output
  rd_obj <- rd_info$rd[[alias_file]]
  if (is.null(rd_obj)) {
    stop("Package help file can't be found")
  }

  # use to_html.rd_doc to convert nicely to a list
  data <- to_html.Rd_doc(rd_obj, pkg = rd_info)

  data$examples <- rd_info$example_text[[alias_file]]
  data$eval_example <- as.character(topic_info$knitr$eval)
  convert_to_text <- function(x) {
    capture.output(dput(x, control = c("keepNA", "keepInteger")))
  }
  topic_info$knitr %>%
    convert_to_text() %>%
    str_replace("^list\\(", "") %>%
    str_replace("\\)$", "") ->
  data$knitr_txt


  data$alias_name <- make_alias_id(alias_file)
  data$id <- valid_id(paste(alias_file, "_", topic_info$index_id, sep = ""))
  data$name <- topic_info$title

  # if (runif(1) < 0.1) {
  #   stop("asdfasdf")
  # }
  # if (alias_file == "test_not_exported.Rd") {
  #   stop("asdfasdf")
  # }

  desc_ind <- which(sapply(data$sections, function(a) {
    if (!is.null(names(a))) {
      if ("title" %in% names(a)) {
        if (a$title == "Description")
          return(TRUE)
      }
    }
    FALSE
  }))

  if (length(desc_ind) > 0) {
    data$description <- data$sections[[desc_ind]]$contents
    data$sections[[desc_ind]] <- NULL
  }

  zero_ind <- which(sapply(data$sections, length) == 0)
  if (length(zero_ind) > 0) {
    data$sections <- data$sections[-zero_ind]
  }

  # rgxp <- "([a-zA-Z0-9\\.\\_]+)\\.html"

  # replace seealso links with hashes
  data$seealso <- fix_hrefs(data$seealso)

  # same for usage
  # data$usage <- fix_hrefs(data$usage)
  # data$usage <- gsub("\\n    ", "\n  ", data$usage)

  for (jj in seq_along(data$sections)) {
    if ("contents" %in% names(data$sections[[jj]])) {
      data$sections[[jj]]$contents <- fix_hrefs(data$sections[[jj]]$contents)
    }
  }
  # "#\\L\\1"

  for (jj in seq_along(data$arguments)) {
    data$arguments[[jj]]$description <- fix_hrefs(data$arguments[[jj]]$description)
  }

  ## other sections assume description to be of length 1
  if (!is.null(data$description)) {
    data$description <- paste(data$description, collapse = "\n")
  }

    ## assuming description may have multiple sentences
  if (data$title == data$description[1]) {
    data$description <- NULL
  }

  data
}


remove_topics_from_index <- function(rd_index, bad_topic_ids) {

  # by going in rev order, sections may be removed without worry
  messages <- c()
  for (ii in rev(seq_along(rd_index))) {
    ii_ids <- alias_id_from_topics(rd_index[[ii]]$topics)
    rd_index[[ii]]$topics <- rd_index[[ii]]$topics[
      ! (ii_ids %in% bad_topic_ids)
    ]

    if (length(rd_index[[ii]]$topics) == 0) {
      messages <- append(messages,
        paste0("Removing section: \"", rd_index[[ii]]$section_name, "\", due to lack of topics"))
      rd_index <- rd_index[-ii]
    }
  }
  lapply(rev(messages), message)

  rd_index
}


alias_files_from_topics <- function(topics) {
  topics %>%
    lapply("[[", "file") %>%
    unlist() %>%
    set_names(alias_id_from_topics(topics))
}
alias_id_from_topics <- function(topics) {
  topics %>%
    lapply("[[", "index_id") %>%
    unlist()
}
alias_files_from_index <- function(rd_index) {
  alias_info_from_index(rd_index) %>%
    alias_files_from_topics()
}
alias_id_from_index <- function(rd_index) {
  alias_info_from_index(rd_index) %>%
    alias_id_from_topics()
}

alias_info_from_index <- function(rd_index) {
  rd_index %>%
    lapply("[[", "topics") %>%
    unlist(recursive = FALSE)
}
