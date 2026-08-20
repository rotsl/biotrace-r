# A carefully-scoped JSON Schema (draft-07) validator.
#
# We deliberately implement a small subset of draft-07 rather than
# pulling in `jsonvalidate` (which would require V8 and a JS runtime,
# bloating the dependency tree). The two upstream schemas
# (biotrace-config.schema.json, biotrace-report.schema.json) only use
# the following keywords:
#
#   type, const, enum, required, properties, additionalProperties,
#   items, oneOf, minimum, maximum
#
# We support exactly those keywords plus the obvious `boolean` and
# `integer` distinction. Anything else is silently ignored (not
# enforced). This is a documented limitation; the upstream schemas do
# not use the unsupported keywords.
#
# The validator is pure R. It walks the schema and the instance
# together and collects every violation into a flat list. The caller
# decides whether to abort (validate_biotrace_config /
# validate_biotrace_report) or to inspect (validate_biotrace_config
# with `return_errors = TRUE`).

# Public wrapper: load the upstream schema, validate `instance`, return
# either TRUE/FALSE or a structured error list.
#
# Returns:
#   - TRUE (invisible) when valid and `return_errors = FALSE`
#   - a list of error objects (possibly empty) when `return_errors = TRUE`
#     and valid
#   - a non-empty list when `return_errors = TRUE` and invalid
# Throws biotrace_invalid_config / biotrace_invalid_report when invalid
# and `return_errors = FALSE`.
.biotrace_validate <- function(instance, schema_kind, path_str,
                               return_errors = FALSE, abort_class = NULL) {
  schema_kind <- match.arg(schema_kind, c("config", "report"))
  schema <- .load_schema(schema_kind)

  errors <- .validate_against_schema(instance, schema, "$")

  if (length(errors) == 0L) {
    if (return_errors) return(list()) else return(invisible(TRUE))
  }

  msgs <- vapply(errors, function(e) {
    paste0(e$path, ": ", e$message)
  }, character(1))

  if (return_errors) {
    return(errors)
  }

  if (is.null(abort_class)) abort_class <- "biotrace_invalid_config"
  abort_msg(
    message = paste0(
      if (schema_kind == "config") {
        "Invalid BioTrace configuration"
      } else {
        "Invalid BioTrace report JSON"
      },
      ".\n", paste(msgs, collapse = "\n")
    ),
    class = c(abort_class, "biotrace_error"),
    errors = errors,
    schema_kind = schema_kind,
    instance_path = path_str
  )
}

# Load and cache the schema JSON. We cache because the schema is read
# many times in the testthat suite (each invocation of
# validate_biotrace_config re-reads it otherwise).
.biotrace_schema_cache <- new.env(parent = emptyenv())

.load_schema <- function(kind) {
  if (!is.null(.biotrace_schema_cache[[kind]])) {
    return(.biotrace_schema_cache[[kind]])
  }
  p <- schema_path(kind)
  raw <- .read_text_utf8(p)
  json <- tryCatch(
    jsonlite::fromJSON(raw, simplifyVector = FALSE),
    error = function(e) {
      abort_json_parse(p, conditionMessage(e))
    }
  )
  if (!is.list(json)) {
    abort_msg(
      paste0("Schema for ", kind, " is not a JSON object: ", p),
      class = c("biotrace_schema_corrupt", "biotrace_error"),
      path = p
    )
  }
  .biotrace_schema_cache[[kind]] <- json
  json
}

# Reset the schema cache. Used by tests to force a clean reload.
.reset_schema_cache <- function() {
  rm(list = ls(envir = .biotrace_schema_cache), envir = .biotrace_schema_cache)
  invisible(NULL)
}

# The recursive core. `path` is a JSON Pointer-like path string for
# error messages ("$" for root, "$.version" for the version field, etc).
.validate_against_schema <- function(instance, schema, path) {
  errors <- list()

  if (!is.list(schema)) {
    # The schema itself is malformed. We do not throw; we collect an
    # error so the caller can decide.
    errors[[length(errors) + 1L]] <- list(
      path = path,
      message = paste0("schema at ", path, " is not an object")
    )
    return(errors)
  }

  # const
  if (!is.null(schema[["const"]])) {
    if (!identical(instance, schema[["const"]])) {
      errors[[length(errors) + 1L]] <- list(
        path = path,
        message = sprintf(
          "must equal %s but is %s",
          .render_value(schema[["const"]]),
          .render_value(instance)
        )
      )
    }
  }

  # enum
  if (!is.null(schema[["enum"]])) {
    ok <- any(vapply(schema[["enum"]], function(v) identical(instance, v),
                     logical(1)))
    if (!ok) {
      errors[[length(errors) + 1L]] <- list(
        path = path,
        message = sprintf(
          "must be one of %s but is %s",
          .render_enum(schema[["enum"]]),
          .render_value(instance)
        )
      )
    }
  }

  # type
  if (!is.null(schema[["type"]])) {
    type_errors <- .check_type(instance, schema[["type"]], path)
    if (length(type_errors) > 0L) {
      errors <- c(errors, type_errors)
      # If the type is wrong, deeper checks would be misleading.
      return(errors)
    }
  }

  # required + properties (only for objects)
  if (!is.null(schema[["required"]]) ||
      !is.null(schema[["properties"]]) ||
      !is.null(schema[["additionalProperties"]])) {
    errors <- c(errors, .check_object(instance, schema, path))
  }

  # items (only for arrays)
  if (!is.null(schema[["items"]])) {
    errors <- c(errors, .check_items(instance, schema[["items"]], path))
  }

  # minimum / maximum (numeric)
  if (!is.null(schema[["minimum"]]) || !is.null(schema[["maximum"]])) {
    errors <- c(errors, .check_numeric_bounds(instance, schema, path))
  }

  # oneOf
  if (!is.null(schema[["oneOf"]])) {
    errors <- c(errors, .check_one_of(instance, schema[["oneOf"]], path))
  }

  errors
}

# Render an R value for inclusion in an error message. We aim for a
# JSON-ish look so users can recognise their own input.
.render_value <- function(v) {
  if (is.null(v)) return("null")
  if (is.character(v) && length(v) == 1L) return(sprintf("%s", encodeString(v, quote = "\"")))
  if (is.logical(v) && length(v) == 1L) return(tolower(as.character(v)))
  if (is.numeric(v) && length(v) == 1L) return(as.character(v))
  if (length(v) > 1L) {
    return(paste0("[", paste(vapply(v, .render_value, character(1)),
                                 collapse = ", "), "]"))
  }
  paste(deparse(v), collapse = "")
}

.render_enum <- function(values) {
  paste(vapply(values, .render_value, character(1)), collapse = ", ")
}

# Type check that handles JSON-style types. Integer in JSON Schema
# includes int-typed numbers but not float-typed ones; R does not
# distinguish at the storage level so we treat any whole-number
# numeric as integer.
#
# JSON/R disambiguation:
#   - JSON "string" => R character vector of length 1
#   - JSON "array"  => R list (named-or-unnamed) OR R atomic vector of
#     length >= 2. A character(1) is a string, not an array, because in
#     R a singleton character vector is indistinguishable from a
#     JSON string. We require length > 1 for atomic vectors to count
#     as arrays; length-1 atomics are treated as scalars.
.check_type <- function(instance, type, path) {
  ok <- switch(type,
    "object" = is.list(instance) && !is.data.frame(instance) && .is_named_object(instance),
    "array"  = (is.list(instance) && !is.data.frame(instance)) ||
               ((is.vector(instance, mode = "integer") ||
                 is.vector(instance, mode = "numeric") ||
                 is.vector(instance, mode = "character") ||
                 is.vector(instance, mode = "logical")) &&
                length(instance) > 1L),
    "string" = is.character(instance) && length(instance) == 1L,
    "integer" = is.numeric(instance) && length(instance) == 1L && !is.na(instance) &&
                as.integer(instance) == instance,
    "number" = is.numeric(instance) && length(instance) == 1L,
    "boolean" = is.logical(instance) && length(instance) == 1L,
    "null" = is.null(instance),
    TRUE # unknown type: do not enforce
  )
  if (isTRUE(ok)) return(list())
  list(list(path = path, message = paste0("must be of type ", type)))
}

# A list counts as a JSON "object" only if every name is non-empty.
# Otherwise it is a JSON "array" (R's idea of an unnamed list).
.is_named_object <- function(x) {
  if (!is.list(x)) return(FALSE)
  if (length(x) == 0L) {
    return(!is.null(attr(x, "names")) || !is.null(names(x)))
  }
  nms <- names(x)
  !is.null(nms) && all(nzchar(nms))
}

.check_object <- function(instance, schema, path) {
  errors <- list()
  if (!is.list(instance) || is.data.frame(instance)) {
    # Not an object; the type check will have already produced a
    # violation. Nothing more to do here.
    return(errors)
  }
  inst_names <- names(instance)
  if (is.null(inst_names)) inst_names <- character(length(instance))

  # required
  if (!is.null(schema[["required"]])) {
    missing <- setdiff(schema[["required"]], inst_names)
    if (length(missing) > 0L) {
      for (m in missing) {
        errors[[length(errors) + 1L]] <- list(
          path = paste0(path, ".", m),
          message = paste0("missing required field \"", m, "\"")
        )
      }
    }
  }

  # properties
  props <- schema[["properties"]]
  if (!is.null(props) && is.list(props)) {
    for (nm in names(instance)) {
      if (nm %in% names(props)) {
        sub <- .validate_against_schema(instance[[nm]], props[[nm]],
                                         paste0(path, ".", nm))
        if (length(sub)) errors <- c(errors, sub)
      } else if (identical(schema[["additionalProperties"]], FALSE)) {
        errors[[length(errors) + 1L]] <- list(
          path = paste0(path, ".", nm),
          message = paste0("additional property not allowed")
        )
      }
    }
  }

  errors
}

.check_items <- function(instance, items, path) {
  errors <- list()
  # We accept both R lists (jsonlite::fromJSON simplifyVector=FALSE)
  # and R atomic vectors (yaml::yaml.load and jsonlite with
  # simplifyVector=TRUE). A data.frame counts as neither.
  if (is.data.frame(instance)) return(errors)
  if (!is.list(instance) && !is.atomic(instance)) return(errors)
  if (length(instance) == 0L) return(errors)
  for (i in seq_along(instance)) {
    sub <- .validate_against_schema(instance[[i]], items, paste0(path, "[", i, "]"))
    if (length(sub)) errors <- c(errors, sub)
  }
  errors
}

.check_numeric_bounds <- function(instance, schema, path) {
  errors <- list()
  if (!is.numeric(instance) || length(instance) != 1L || is.na(instance)) {
    return(errors)
  }
  if (!is.null(schema[["minimum"]]) && instance < schema[["minimum"]]) {
    errors[[length(errors) + 1L]] <- list(
      path = path,
      message = sprintf("must be >= %s but is %s",
                       schema[["minimum"]], instance)
    )
  }
  if (!is.null(schema[["maximum"]]) && instance > schema[["maximum"]]) {
    errors[[length(errors) + 1L]] <- list(
      path = path,
      message = sprintf("must be <= %s but is %s",
                       schema[["maximum"]], instance)
    )
  }
  errors
}

.check_one_of <- function(instance, subschemas, path) {
  # oneOf: exactly one subschema must validate.
  matched <- 0L
  for (sub in subschemas) {
    errs <- .validate_against_schema(instance, sub, path)
    if (length(errs) == 0L) matched <- matched + 1L
  }
  if (matched != 1L) {
    list(list(path = path, message = sprintf(
      "must match exactly one of the oneOf alternatives (matched %d)",
      matched
    )))
  } else {
    list()
  }
}

# Validate the contents of a file (YAML or JSON) given its kind.
# Returns either TRUE (invisible) or throws.
.biotrace_validate_file <- function(path, kind, return_errors = FALSE) {
  if (!.exists_file(path)) abort_file_missing(path)
  text <- .read_text_utf8(path)
  if (kind == "config") {
    # Use a seq handler so single-element YAML arrays stay as lists
    # rather than collapsing to atomic scalars. The yaml package
    # otherwise turns `[R]` into `chr "R"`, which would fail the
    # JSON Schema `type: array` check.
    obj <- tryCatch(
      yaml::yaml.load(text, handlers = list(seq = function(x) as.list(x))),
      error = function(e) {
        abort_yaml_parse(path, conditionMessage(e))
      }
    )
  } else {
    obj <- tryCatch(
      jsonlite::fromJSON(text, simplifyVector = FALSE),
      error = function(e) {
        abort_json_parse(path, conditionMessage(e))
      }
    )
  }
  if (is.null(obj)) {
    # Empty file. Both schemas require at least `version` (config) or
    # `schema_version` etc. (report). We let the schema validator flag
    # the missing fields, but first we coerce to an empty object so the
    # validator does not choke on NULL.
    obj <- list()
  }
  abort_class <- if (kind == "config") "biotrace_invalid_config" else "biotrace_invalid_report"
  .biotrace_validate(obj, kind, path, return_errors = return_errors,
                    abort_class = abort_class)
}
