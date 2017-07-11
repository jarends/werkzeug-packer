Path   = require 'path'
Packer = require './packer'
error  = null
cfg    =
    watch:        false
    bundles:      []
    base:         process.cwd()
    useBabel:     true
    useUglify:    false
    loaderPrefix: 'es6-promise!'
    chunks:       './js/chunk_'
    fffMaps:      true
    externalMaps: false


pathForFlag = (path, flag, name) ->
    if /^-\w$|^-\w\w$/.test path
        error = name + ' expected behind ' + flag + ' flag. Got another flag: ' + path
        path  = null
    else if not path or not path.length
        error = name + ' expected behind ' + flag + ' flag.'
        path  = null
    path



cfgFromArgs = () ->
    args    = process.argv.slice 2
    index   = 0
    while index < args.length
        switch arg = args[index]
            when '-p' or '--pack'
                inPath  = pathForFlag args[index + 1], arg, 'Input path'
                if not error
                    outPath = pathForFlag args[index + 2], arg, 'Output path' if not error
                    if error
                        outPath = inPath.replace /\.js$/, '.pack.js'
                        error   = null
                        index   = index + 2
                        cfg.bundles.push
                            in:  inPath
                            out: outPath
                    else
                        index = index + 3
                        cfg.bundles.push
                            in:  inPath
                            out: outPath

            when '-bp' or '--base-path'
                basePath = pathForFlag args[index + 1], arg, 'Base path'
                if not error
                    if Path.isAbsolute basePath
                        cfg.base = basePath
                    else
                        cfg.base = Path.resolve process.cwd(), basePath
                    index = index + 2

            when '-w' or '--watch'
                use = args[index + 1]
                if use == 'false' or use == 'true'
                    cfg.watch = use == 'true'
                    index = index + 2
                else
                    cfg.watch = true
                    ++index

            when '-ub' or '--use-babel'
                use = args[index + 1]
                if use == 'false' or use == 'true'
                    cfg.useBabel = use == 'true'
                    index = index + 2
                else
                    cfg.useBabel = true
                    ++index

            when '-uu' or '--use-uglify'
                use = args[index + 1]
                if use == 'false' or use == 'true'
                    cfg.useUglify = use == 'true'
                    index = index + 2
                else
                    cfg.useUglify = true
                    ++index

            when '-im' or '--inline-maps'
                use = args[index + 1]
                if use == 'false' or use == 'true'
                    cfg.fffMaps = use == 'true'
                    index = index + 2
                else
                    cfg.fffMaps = true
                    ++index

            when '-em' or '--external-maps'
                use = args[index + 1]
                if use == 'false' or use == 'true'
                    cfg.externalMaps = use == 'true'
                    index = index + 2
                else
                    cfg.externalMaps = true
                    ++index

            when '-lp' or '--loader-prefix'
                prefix = args[index + 1]
                if not prefix
                    error = 'Prefix expected behind ' + arg + ' flag.'
                if /^-\w$/.test prefix
                    error = 'Prefix expected behind ' + arg + ' flag. Got another flag: ' + prefix
                else
                    cfg.loaderPrefix = prefix
                    index = index + 2

            when '-cp' or '--chunk-prefix'
                prefix = args[index + 1]
                if not prefix
                    error = 'Prefix expected behind ' + arg + ' flag.'
                if /^-\w$/.test prefix
                    error = 'Prefix expected behind ' + arg + ' flag. Got another flag: ' + prefix
                else
                    cfg.chunks = prefix
                    index = index + 2
            else
                error = 'Unknown or unexpected argument: ' + arg

        return if error
    null


cfgFromArgs()


if error
    console.log 'Error: ', error
else
    packer = new Packer cfg



