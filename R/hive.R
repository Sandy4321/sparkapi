

create_hive_context <- function(sc) {
  if (spark_version(sc) >= "2.0.0")
    create_hive_context_v2(sc)
  else
    create_hive_context_v1(sc)
}

create_hive_context_v2 <- function(sc) {

  # SparkSession.builder().enableHiveSupport()
  builder <- invoke_static(
    sc,
    "org.apache.spark.sql.SparkSession",
    "builder"
  )

  builder <- invoke(
    builder,
    "enableHiveSupport"
  )

  session <- invoke(
    builder,
    "getOrCreate"
  )

  # get config object
  conf <- invoke(session, "conf")

  # apply spark.session. params
  params <- connection_config(sc, "spark.session.")
  apply_config(params, conf, "set")

  # apply spark.sql. params
  params <- connection_config(sc, "spark.sql.")
  apply_config(params, conf, "set")

  # return session as hive context
  session
}

create_hive_context_v1 <- function(sc) {

  # get spark_context
  ctx <- spark_context(sc)

  # attempt to create hive_context
  hive_context <- tryCatch({
    invoke_new(
      sc,
      "org.apache.spark.sql.hive.HiveContext",
      ctx
    )},
    error = function(e) {
      NULL
    }
  )

  # if we failed then create a SqlContext instead
  if (is.null(hive_context)) {

    warning("Failed to create Hive context, falling back to SQL. Some operations, ",
            "like window-functions, will not work")

    jsc <- invoke_static(
      sc,
      "org.apache.spark.api.java.JavaSparkContext",
      "fromSparkContext",
      ctx
    )

    hive_context <- invoke_static(
      sc,
      "org.apache.spark.sql.api.r.SQLUtils",
      "createSQLContext",
      jsc
    )
  }

  # apply configuration
  params <- connection_config(sc, "spark.sql.")
  apply_config(params, hive_context, "setConf")

  # return hive_context
  hive_context
}

apply_config <- function(params, object, method) {

  lapply(names(params), function(paramName) {
    configValue <- params[[paramName]]
    if (is.logical(configValue)) {
      configValue <- if (configValue) "true" else "false"
    }
    else {
      as.character(configValue)
    }

    invoke(
      object,
      method,
      paramName,
      configValue
    )
  })
}
