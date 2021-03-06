# nolint start

#      Vignettes are normally processed by 'Sweave', but package writers
#      may choose to use a different engine (e.g., one provided by the
#      'knitr', 'noweb' or 'R.rsp' packages).  This function is used by
#      those packages to register their engines, and internally by R to
#      retrieve them.
#
#      vignetteEngine(name, weave, tangle, pattern = NULL,
#                     package = NULL, aspell = list())
#
# Arguments:
#
#     name: the name of the engine.
#    weave: a function to convert vignette source files to LaTeX output.
#   tangle: a function to convert vignette source files to R code.
#  pattern: a regular expression pattern for the filenames handled by
#           this engine, or 'NULL' for the default pattern.
#  package: the package registering the engine.  By default, this is the
#           package calling 'vignetteEngine'.
#   aspell: a list with element names 'filter' and/or 'control' giving
#           the respective arguments to be used when spell checking the
#           text in the vignette source file with 'aspell'.
#
# Details:
#
#      If 'weave' is missing, 'vignetteEngine' will return the currently
#      registered engine matching 'name' and 'package'.
#
#      If 'weave' is 'NULL', the specified engine will be deleted.
#
#      Other settings define a new engine. The 'weave' and 'tangle'
#      functions must be defined with argument lists compatible with
#      'function(file, ...)'. Currently the '...' arguments may include
#      logical argument 'quiet' and character argument 'encoding'; others
#      may be added in future. These are described in the documentation
#      for 'Sweave' and 'Stangle'.
#      The 'weave' and 'tangle' functions should return the filename of
#          the output file that has been produced. Currently the 'weave'
#          function, when operating on a file named '<name> <pattern>' must
#          produce a file named '<name>[.](tex|pdf|html)'. The '.tex' files
#          will be processed by 'pdflatex' to produce '.pdf' output for
#          display to the user; the others will be displayed as produced.
#          The 'tangle' function must produce a file named '<name>[.][rRsS]'
#          containing the executable R code from the vignette.  The 'tangle'
#          function may support a 'split = TRUE' argument, and then it should
#          produce files named '<name>.*[.][rRsS]'.
#
#          The 'pattern' argument gives a regular expression to match the
#          extensions of files which are to be processed as vignette input
#          files. If set to 'NULL', the default pattern
#          '"[.][RrSs](nw|tex)$' is used.
#
#     Value:
#
#          If the engine is being deleted, 'NULL'.  Otherwise a list
#          containing components
#
#         name: The name of the engine
#
#      package: The name of its package
#
#      pattern: The pattern for vignette input files
#
#        weave: The weave function
#
#       tangle: The tangle function
#
#     Author(s):
#
#          Duncan Murdoch and Henrik Bengtsson.
#
#     See Also:
#
#          'Sweave' and the 'Writing R Extensions' manual.
#
#     Examples:
#
#          str(vignetteEngine("Sweave"))
#
#

# $`knitr::knitr_notangle`
# $`knitr::knitr_notangle`$name
# [1] "knitr_notangle"
#
# $`knitr::knitr_notangle`$package
# [1] "knitr"
#
# $`knitr::knitr_notangle`$pattern
# [1] "[.]([rRsS](nw|tex)|[Rr](md|html|rst))$"
#
# $`knitr::knitr_notangle`$weave
# function (file, driver, syntax, encoding = "UTF-8", quiet = FALSE,
#     ...)
# {
#     {
#         on.exit({
#             opts_chunk$restore()
#             knit_hooks$restore()
#         }, add = TRUE)
#         oopts = options(markdown.HTML.header = NULL)
#         on.exit(options(oopts), add = TRUE)
#     }
#     opts_chunk$set(error = FALSE)
#     {
#     }
#     (if (grepl("\\.[Rr]md$", file))
#         knit2html
#     else if (grepl("\\.[Rr]rst$", file))
#         knit2pdf
#     else knit)(file, encoding = encoding, quiet = quiet, envir = globalenv())
# }
# <environment: namespace:knitr>
#
# $`knitr::knitr_notangle`$tangle
# function (file, ...)
# {
#     unlink(sub_ext(file, "R"))
#     return()
# }
# <environment: namespace:knitr>

# nolint end

.onLoad <- function(lib, pkg) {

  #     name: the name of the engine.
  #    weave: a function to convert vignette source files to LaTeX output.
  #   tangle: a function to convert vignette source files to R code.
  #  pattern: a regular expression pattern for the filenames handled by
  #           this engine, or 'NULL' for the default pattern.
  #  package: the package registering the engine.  By default, this is the
  #           package calling 'vignetteEngine'.
  #   aspell: a list with element names 'filter' and/or 'control' giving
  #           the respective arguments to be used when spell checking the
  #           text in the vignette source file with 'aspell'.

  redirect_weaver <- function(file, ...) {
    output_file <- gsub(".Rmd$", ".html", file)
    render_redirect(
      input_file_rmd = file,
      output_file_html = output_file
    )
    return(output_file)
  }
  tangler <- function(...) {
    # do not create an R file with all the R code.
    return()
  }

  tools::vignetteEngine(
    name = "redirect",
    weave = redirect_weaver,
    tangle = tangler,
    pattern = "\\.Rmd$",
    package = "packagedocs"
  )

}
