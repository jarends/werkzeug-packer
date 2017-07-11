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


getVersion: () ->


getVersion = () ->
    p = require Path.resolve(__dirname, '../package.json')
    p.version




printHelp = () ->
    console.log """

werkzeug-packer can be configured using the following flags:

-p  --pack          [file] [file?]  Specify the input file and optional an output file.
                                    If the output file is omitted, the input file's name is used
                                    with a 'pack' inserted before the extension:
                                    e.g.: main.js -> main.pack.js
                                    Can be used multiple times for each module to bundle.
-w  --watch                         Start watching and repack on changes.
-bp --base-path     [file]          Specify a base path to resolve relative files used with -p flag.
-ub --use-babel     [bool?]         To disable babel enter false. The default is true.
-uu --use-uglify    [bool?]         To uglify input sources enter true. The default is false.
-im --inline-maps   [bool?]         To inline sources in maps enter true. The default is false.
-em --external-maps [bool?]         To include external maps enter true. The default is false.
-cp --chunk-prefix  [path]          Enter a path and/or a file prefix for all packed chunks.
                                    The default is './js/chunk_'.
-lp --loader-prefix [string]        Enter a string to prifix required path's for chunk loading.
                                    The default is 'es6-promise!'.
-ne --node-env      [string]        Enter a value to set in window.process.env.NODE_ENV.
                                    The default is 'development'.
-v  --version                       Prints the version (#{getVersion()}).
-h  --help                          Prints this help.

"""
    null




pathForFlag = (path, flag, name) ->
    if /^-\w$|^-\w\w$/.test path
        error = name + ' expected behind ' + flag + ' flag. Got another flag: ' + path
        path  = null
    else if not path or not path.length
        error = name + ' expected behind ' + flag + ' flag.'
        path  = null
    path



cfgFromArgs = () ->
    args  = process.argv.slice 2
    args  = ['-h'] if args.length == 0
    index = 0

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

            when '-w' or '--watch'
                use = args[index + 1]
                if use == 'false' or use == 'true'
                    cfg.watch = use == 'true'
                    index = index + 2
                else
                    cfg.watch = true
                    ++index

            when '-h' or '--help'
                if args.length > 1
                    error = '-h or --help must be used as single flag'
                else
                    printHelp()
                ++index

            when '-v' or '--version'
                if args.length > 1
                    error = '-v or --version must be used as single flag'
                else
                    console.log getVersion()
                ++index

            when '-bp' or '--base-path'
                basePath = pathForFlag args[index + 1], arg, 'Base path'
                if not error
                    if Path.isAbsolute basePath
                        cfg.base = basePath
                    else
                        cfg.base = Path.resolve process.cwd(), basePath
                    index = index + 2

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
                value = args[index + 1]
                if not value
                    error = 'Prefix expected behind ' + arg + ' flag.'
                if /^-\w$/.test value
                    error = 'Prefix expected behind ' + arg + ' flag. Got another flag: ' + value
                else
                    cfg.loaderPrefix = value
                    index = index + 2

            when '-cp' or '--chunk-prefix'
                value = args[index + 1]
                if not value
                    error = 'Prefix expected behind ' + arg + ' flag.'
                if /^-\w$/.test value
                    error = 'Prefix expected behind ' + arg + ' flag. Got another flag: ' + value
                else
                    cfg.chunks = value
                    index = index + 2

            when '-ne' or '--node-env'
                value = args[index + 1]
                if not value
                    error = 'Value expected behind ' + arg + ' flag.'
                if /^-\w$/.test value
                    error = 'Value expected behind ' + arg + ' flag. Got another flag: ' + value
                else
                    cfg.NODE_ENV = value
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



