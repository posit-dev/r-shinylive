assert_nzchar_string <- function(x) {
  stopifnot(is.character(x) && nchar(x) > 0)
  invisible(TRUE)
}
assert_list_items <- function(x, item_class) {
  stopifnot(is.list(x) && all(vapply(x, inherits, logical(1), item_class)))
  invisible(TRUE)
}
assert_list <- function(x) {
  stopifnot(is.list(x))
  invisible(TRUE)
}


unlink_path <- function(path) {
  if (fs::dir_exists(path)) {
    if (fs::is_link(path)) {
      fs::link_delete(path)
    } else {
      fs::dir_delete(path)
    }
  }
}


collapse <- function(...) {
  paste0(..., collapse = "\n")
}

package_json_version <- function(source_dir) {
  package_json_path <- fs::path(source_dir, "package.json")
  if (!fs::file_exists(package_json_path)) {
    stop("package.json does not exist in ", source_dir)
  }

  package_json <- jsonlite::read_json(package_json_path)
  package_json$version
}


files_are_equal <- function(x_file_path, y_file_path) {
  tools::md5sum(x_file_path) == tools::md5sum(y_file_path)
}

drop_nulls_rec <- function(x) {
  if (is.list(x)) {
    # Recurse
    x <- lapply(x, drop_nulls_rec)
    is_null <- vapply(x, is.null, logical(1))
    x[!is_null]
  } else {
    # Return as is. Let parent list handle it
    x
  }
}



# """Returns a function that can be used as a copy_function for shutil.copytree.
#
# If overwrite is True, the copy function will overwrite files that already exist.
# If overwrite is False, the copy function will not overwrite files that already exist.
# """
# Using base file methods in this function because `{fs}` is slow.
create_copy_fn <- function(
    overwrite = FALSE,
    verbose_print = list # or `message`
    ) {
  overwrite <- isTRUE(overwrite)
  stopifnot(is.function(verbose_print))

  function(src_file_path, dst_file_path) {
    if (file.exists(dst_file_path)) {
      if (!files_are_equal(src_file_path, dst_file_path)) {
        message(
          "\nSource and destination copies differ:", dst_file_path,
          "\nThis is probably because your shinylive sources have been updated and differ from the copy in the exported app.",
          "\nYou probably should remove the export directory and re-export the application.",
        )
      }
      if (overwrite) {
        verbose_print(paste0("\nRemoving ", dst_file_path))
        unlink_path(dst_file_path)
      } else {
        verbose_print(paste0("\nSkipping ", dst_file_path))
        return()
      }
    } else {
      # Make sure destination's parent directory exists
      parent_dir <- dirname(dst_file_path)
      if (!dir.exists(parent_dir)) {
        dir.create(parent_dir, recursive = TRUE)
      }
      # fs::dir_create(fs::path_dir(dst_file_path))
    }
    # Copy file
    file.copy(src_file_path, dst_file_path)
    # fs::file_copy(src_file_path, dst_file_path)
  }
}
