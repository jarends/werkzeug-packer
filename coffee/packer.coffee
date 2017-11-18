FS                 = require 'fs'
FSE                = require 'fs-extra'
Path               = require 'path'
Dict               = require 'jsdictionary'
JMin               = require 'jsonminify'
EMap               = require 'emap'
PACK_CODE          = FS.readFileSync Path.join(__dirname, '../js', 'pack.js'),  'utf8'
CHUNK_CODE         = FS.readFileSync Path.join(__dirname, '../js', 'chunk.js'), 'utf8'
MULTI_COMMENT_MAP  = /\/\*\s*[@#]\s*sourceMappingURL\s*=\s*([^\s]*)\s*\*\//g
SINGLE_COMMENT_MAP = /\/\/\s*[@#]\s*sourceMappingURL\s*=\s*([^\s]*)($|\n|\r\n?)/g
ENV                = 'development'
CSS_REG            = /\.sass$|\.scss$|\.less$|\.styl$/
JS_REG             = /\.coffee$|\.ts$/
Babel              = null
Babel_es2015       = null
Chok               = null




#     0000000   0000000   0000000    00000000
#    000       000   000  000   000  000     
#    000       000   000  000   000  0000000 
#    000       000   000  000   000  000     
#     0000000   0000000   0000000    00000000

getPackCode = (p) -> """
(function(pack)
{
    var win = window,
        process = win.process || (win.process = {}),
        env     = process.env || (process.env = {}),
        cfg     = {
        index:      #{p.index},
        total:      #{p.total},
        startIndex: #{p.file.index},
        type:       'addPack#{p.id}',
        path:       '#{p.file.path}',
        pack:       pack
    };
    env.NODE_ENV = env.NODE_ENV || '#{p.env}'
    var packer = #{if p.index == 0 then PACK_CODE else CHUNK_CODE}
    packer.init(cfg);
})({
#{p.code}
});"""


getChunkCode = (p) -> """
(function(pack)
{
    var cfg = {
        type:       'addPack#{p.id}',
        path:       '#{p.file.path}',
        chunk:      '#{p.chunk}',
        pack:       pack
    };
    var chunk = #{CHUNK_CODE}
    chunk.init(cfg);
})({
#{p.code}
});"""




#    000  000   000  0000000    00000000  000   000  00000000  00000000 
#    000  0000  000  000   000  000        000 000   000       000   000
#    000  000 0 000  000   000  0000000     00000    0000000   0000000  
#    000  000  0000  000   000  000        000 000   000       000   000
#    000  000   000  0000000    00000000  000   000  00000000  000   000

class Indexer

    constructor: () ->
        @current = -1
        @cache   = {}

    get: (path) ->
        cached = @cache[path]
        if not isNaN cached
            return cached
        @cache[path] = ++@current
        @current


    has: (path) ->
        not isNaN @cache[path]








#    00000000    0000000    0000000  000   000  00000000  00000000 
#    000   000  000   000  000       000  000   000       000   000
#    00000000   000000000  000       0000000    0000000   0000000  
#    000        000   000  000       000  000   000       000   000
#    000        000   000   0000000  000   000  00000000  000   000

class Packer

    constructor: (@cfg) ->
        @indexer    = new Indexer()
        @emap       = new EMap()
        @fileMap    = {}    # indexing: files mapped by path in tmp or node_modules
        @loaders    = {}    # indexing: map of all parsed loaders by path
        @openFiles  = 0     # indexing: number of currently reading files
        @packed     = null  # packaging: map of already packed files
        @loaded     = null  # packaging: map of chunks loaded by a loader
        @packs      = null  # packaging: list of current packs
        @chunks     = null  # packaging: list of current chunks
        @errors     = []
        @updates    = []
        @id         = ''
        @useBabel   = @cfg.useBabel  != false
        @useUglify  = @cfg.useUglify == true
        @NODE_ENV   = @cfg.NODE_ENV or ENV
        @out        = @cfg.base

        if @cfg.watch
            @watch()

        bundles = @cfg.bundles or []
        for bundle in bundles
            @readFile Path.join(@out, bundle.in)




    #    000   000   0000000   000000000   0000000  000   000  000  000   000   0000000 
    #    000 0 000  000   000     000     000       000   000  000  0000  000  000      
    #    000000000  000000000     000     000       000000000  000  000 0 000  000  0000
    #    000   000  000   000     000     000       000   000  000  000  0000  000   000
    #    00     00  000   000     000      0000000  000   000  000  000   000   0000000 

    watch: () ->
        if @watcher
            @emap.all()
            @watcher.close()

        Chok = Chok or require 'chokidar'
        @watcher = Chok.watch null,
            ignoreInitial: true
            usePolling:    false
            useFsEvents:   true

        @emap.map @watcher, 'add',    @addedHandler,    @
        @emap.map @watcher, 'change', @changedHandler,  @
        @emap.map @watcher, 'unlink', @unlinkedHandler, @
        null


    updateLater: () ->
        clearTimeout @updateTimeout
        @updateTimeout = setTimeout @updateNow, 100
        null



    updateNow: () =>
        if @openFiles > 0
            @updateLater()
        else
            @update @updates
            @updates = []
        null


    addedHandler: (path) ->
        if @indexer.has path
            #console.log 'file added: ', path
            @updates.push path: path
            @updateLater()
        null


    changedHandler: (path) ->
        if @indexer.has path
            #console.log 'file changed: ', path
            @updates.push path: path
            @updateLater()
        null


    unlinkedHandler: (path) ->
        #console.log 'file unlinked: ', path
        @updates.push
            path:    path
            removed: true
        @updateLater()
        null




    #    000   000  00000000   0000000     0000000   000000000  00000000
    #    000   000  000   000  000   000  000   000     000     000     
    #    000   000  00000000   000   000  000000000     000     0000000 
    #    000   000  000        000   000  000   000     000     000     
    #     0000000   000        0000000    000   000     000     00000000

    update: (files) ->
        try
            errors  = @errors
            @errors = []
            updated = {}
            for f in files
                path = f.path
                file = @fileMap[path]
                #console.log 'update file: ', path, f.path
                continue if not file or updated[path]
                updated[path] = true
                @clear file
                if not f.removed
                    @readFile path

            for error in errors
                path = error.path
                file = @fileMap[path]
                continue if updated[path]
                updated[path] = true
                @clear file
                @readFile path

            @writePackages() if @openFiles == 0
            @completed()     if @openFiles == 0

        catch e
            console.log 'packer error: ', e.toString()
        null




    clear: (file) ->
        path = file.path
        for reqPath of file.req
            req = @fileMap[reqPath]
            delete req.ref[path] if req
            delete file.req[reqPath]

        for loderPath of file.reqAsL
            loaderRefs = @loaders[loderPath]
            if loaderRefs
                delete loaderRefs[path]
                if not Dict.hasKeys loaderRefs
                    delete @loaders[loderPath]
            delete file.reqAsL[loderPath]

        delete @fileMap[path]
        null




    #    000   000  00000000   000  000000000  00000000        00000000    0000000    0000000  000   000
    #    000 0 000  000   000  000     000     000             000   000  000   000  000       000  000 
    #    000000000  0000000    000     000     0000000         00000000   000000000  000       0000000  
    #    000   000  000   000  000     000     000             000        000   000  000       000  000 
    #    00     00  000   000  000     000     00000000        000        000   000   0000000  000   000
    
    writePackages: () ->
        #console.log 'write packs...'
        # remove current packs and chunks
        @removeSources(pack.out)  for pack  in @packs  if @packs
        @removeSources(chunk.out) for chunk in @chunks if @chunks


        @totalModules = 0
        @packed       = {}
        @loaded       = {}
        @packs        = []
        @chunks       = []
        packages      = @cfg.bundles or []

        # clear loader data
        for path of @fileMap
            file = @fileMap[path]
            file.loaders = {}
            file.parts   = {}

        # create packs and gather all requireds
        for pack, i in packages by -1
            path = Path.join @out, pack.in
            file = @fileMap[path]

            continue if file.error

            p =
                file:       file
                index:      i
                total:      packages.length
                id:         @id
                out:        Path.join @out, pack.out
                req:        {}
                loaders:    {}
                code:       ''
                env:        @NODE_ENV
                numModules: 0

            @packs.push p
            @gatherReq p, file

        # gather all modules for each loader
        for path of @loaders
            loader = @fileMap[path]
            @gatherChunks loader, loader

        # cleanup modules required by each loader
        for path of @loaded
            @cleanupChunks @fileMap[path]

        # write packs
        for p in @packs
            @writePack p

        # write chunks
        for path of @loaders
            loader = @fileMap[path]
            chunk  = @getChunkPath loader

            continue if loader.error

            p =
                file:       loader
                index:      loader.index
                id:         @id
                out:        Path.join @out, chunk
                chunk:      chunk
                code:       ''
                numModules: 0

            @chunks.push p
            @writeChunk p

        @completed() if @openFiles == 0
        null


    getChunkPath: (loader) ->
        @cfg.chunks + loader.index + '.js'




    #     0000000    0000000   000000000  000   000  00000000  00000000         00000000   00000000   0000000 
    #    000        000   000     000     000   000  000       000   000        000   000  000       000   000
    #    000  0000  000000000     000     000000000  0000000   0000000          0000000    0000000   000 00 00
    #    000   000  000   000     000     000   000  000       000   000        000   000  000       000 0000 
    #     0000000   000   000     000     000   000  00000000  000   000        000   000  00000000   00000 00

    gatherReq: (p, file) ->
        if @packed[file.index]
            return null
        @packed[file.index] = true
        p.req[file.path]    = true
        for rpath of file.req
            rfile = @fileMap[rpath]
            if not rfile
                @errors.push
                    path:  file.path
                    line:  -1
                    col:   -1
                    error: 'required file not found: ' + rpath
            else if not @packed[rfile.index]
                # add all loaders to the pack -> used by cleanupChunks
                for lpath of rfile.reqAsL
                    p.loaders[lpath] = true
                @gatherReq(p, rfile)
        null




    #     0000000    0000000   000000000  000   000  00000000  00000000          0000000  000   000  000   000  000   000  000   000   0000000
    #    000        000   000     000     000   000  000       000   000        000       000   000  000   000  0000  000  000  000   000     
    #    000  0000  000000000     000     000000000  0000000   0000000          000       000000000  000   000  000 0 000  0000000    0000000 
    #    000   000  000   000     000     000   000  000       000   000        000       000   000  000   000  000  0000  000  000        000
    #     0000000   000   000     000     000   000  00000000  000   000         0000000  000   000   0000000   000   000  000   000  0000000 

    gatherChunks: (loader, file) ->
        file.loaders[loader.path] = true
        loader.parts[file.path]   = true
        @loaded[file.path]        = true
        for rpath of file.req
            rfile = @fileMap[rpath]
            if not rfile
                @errors.push
                    path:  file.path
                    line:  -1
                    col:   -1
                    error: 'required file not found (chunk): ' + rpath
            else
                @gatherChunks(loader, rfile) if not loader.parts[rpath]
        null




    #     0000000  000      00000000   0000000   000   000  000   000  00000000          0000000  000   000  000   000  000   000  000   000   0000000
    #    000       000      000       000   000  0000  000  000   000  000   000        000       000   000  000   000  0000  000  000  000   000     
    #    000       000      0000000   000000000  000 0 000  000   000  00000000         000       000000000  000   000  000 0 000  0000000    0000000 
    #    000       000      000       000   000  000  0000  000   000  000              000       000   000  000   000  000  0000  000  000        000
    #     0000000  0000000  00000000  000   000  000   000   0000000   000               0000000  000   000   0000000   000   000  000   000  0000000 

    cleanupChunks: (file) ->
        # returns a loader, if the file is required by exactly one loader
        loader = @getLoader file
        path   = file.path
        packed = @packed[file.index]
        # remove file from loaders, if already packed
        if packed or not loader
            for lpath of file.loaders
                loader = @fileMap[lpath]
                delete loader.parts[path]
                delete file.loaders[lpath]
                # add file to the first matching pack if not already packed
                if not packed
                    for p in @packs
                        if p.loaders[lpath]
                            p.req[path]         = true
                            @packed[file.index] = true
                            packed              = true
                            break
        null




    #     0000000   00000000  000000000        000       0000000    0000000   0000000    00000000  00000000 
    #    000        000          000           000      000   000  000   000  000   000  000       000   000
    #    000  0000  0000000      000           000      000   000  000000000  000   000  0000000   0000000  
    #    000   000  000          000           000      000   000  000   000  000   000  000       000   000
    #     0000000   00000000     000           0000000   0000000   000   000  0000000    00000000  000   000

    getLoader: (file) ->
        count = 0
        for path of file.loaders
            ++count
            return null if count > 1
        @fileMap[path]




    #     0000000   0000000   000   000  00000000    0000000  00000000  00     00   0000000   00000000    0000000
    #    000       000   000  000   000  000   000  000       000       000   000  000   000  000   000  000     
    #    0000000   000   000  000   000  0000000    000       0000000   000000000  000000000  00000000   0000000 
    #         000  000   000  000   000  000   000  000       000       000 0 000  000   000  000             000
    #    0000000    0000000    0000000   000   000   0000000  00000000  000   000  000   000  000        0000000 

    initSourceMapping: (pack, type) ->
        if type == 'pack'
            if pack.index == 0
                @lineOffset = 183
            else
                @lineOffset = 54
        else
            @lineOffset = 48

        origin     = Path.basename pack.out
        @sourceMap =
            version : 3
            file:     origin
            sourceRoot: ''
            sources: [
                origin
            ]
            sections: []
        null


    addSourceMap: (pack, file, singleLine) ->
        @lineOffset += if singleLine then 2 else 3

        map = file.sourceMap
        if map
            out            = Path.dirname pack.out
            srcBase        = Path.resolve Path.dirname(file.path), map.sourceRoot or ''
            map.file       = Path.relative out, file.path
            map.sourceRoot = ''
            for source, i in map.sources
                map.sources[i] = Path.relative out, Path.resolve(srcBase, source)

            @sourceMap.sections.push
                offset:
                    line:   @lineOffset
                    column: 0
                map: map

        @lineOffset += 1 + (if singleLine then 1 else file.numLines)
        null


    writeSourceMap: (pack) ->
        mapOut = pack.out + '.map'
        FSE.ensureFileSync mapOut
        FS.writeFileSync mapOut, JSON.stringify(@sourceMap), 'utf8'
        pack.code += "\r\n//# sourceMappingURL=#{Path.basename mapOut}"
        null




    #    000   000  00000000   000  000000000  00000000        00000000    0000000    0000000  000   000
    #    000 0 000  000   000  000     000     000             000   000  000   000  000       000  000 
    #    000000000  0000000    000     000     0000000         00000000   000000000  000       0000000  
    #    000   000  000   000  000     000     000             000        000   000  000       000  000 
    #    00     00  000   000  000     000     00000000        000        000   000   0000000  000   000

    writePack: (p) ->
        #console.log 'write pack: ', Path.relative(@cfg.base, p.file.path), '->', Path.relative(@cfg.base, p.out)
        @initSourceMapping(p, 'pack')
        @addSource p, @fileMap[path] for path of p.req
        p.code = p.code.slice 0, -3
        p.code = getPackCode p
        ++@openFiles
        @writeSourceMap p

        #TODO: handle write errors
        FSE.ensureFileSync p.out
        FS.writeFile p.out, p.code, 'utf8', (error) =>
            --@openFiles
            if error
                console.log 'ERROR in packer.writePack: ', Path.relative(@cfg.base, p.out)
            if @openFiles == 0
                @completed()
            null
        null




    #    000   000  00000000   000  000000000  00000000         0000000  000   000  000   000  000   000  000   000
    #    000 0 000  000   000  000     000     000             000       000   000  000   000  0000  000  000  000 
    #    000000000  0000000    000     000     0000000         000       000000000  000   000  000 0 000  0000000  
    #    000   000  000   000  000     000     000             000       000   000  000   000  000  0000  000  000 
    #    00     00  000   000  000     000     00000000         0000000  000   000   0000000   000   000  000   000

    writeChunk: (p) ->
        @initSourceMapping(p, 'chunk')
        @addSource p, @fileMap[path] for path of p.file.parts
        p.code = p.code.slice 0, -3
        p.code = getChunkCode p
        ++@openFiles
        @writeSourceMap p

        #TODO: handle write errors
        FSE.ensureFileSync p.out
        FS.writeFile p.out, p.code, 'utf8', (error) =>
            --@openFiles
            if error
                console.log 'ERROR in packer.writeChunk: ', Path.relative(@cfg.base, p.out)
            if @openFiles == 0
                @completed()
            null
        null




    #     0000000   0000000    0000000           0000000   0000000   000   000  00000000    0000000  00000000
    #    000   000  000   000  000   000        000       000   000  000   000  000   000  000       000     
    #    000000000  000   000  000   000        0000000   000   000  000   000  0000000    000       0000000 
    #    000   000  000   000  000   000             000  000   000  000   000  000   000  000       000     
    #    000   000  0000000    0000000          0000000    0000000    0000000   000   000   0000000  00000000

    addSource: (p, file) ->
        ++@totalModules
        ++p.numModules
        source   = file.source
        source   = nga(source, add:true).src if @nga
        moduleId = Path.relative @out, file.path

        code = "// #{file.path}\r\n#{file.index}: "
        if /.js$/.test file.path
            code += "function(module, exports, require) {\r\nmodule.id = '#{moduleId}';\r\n#{source}\r\n},\r\n"
            @addSourceMap p, file, false

        else
            # replace ' with \'
            source = source.replace /'/g, (args...) ->
                if args[2][args[1] - 1] != '\\' then "\\'" else "'"

            #TODO: check, if this causes problems with JMin
            # surround with quotes
            source = "'#{source}'"

            #TODO: maybe do JSON.parse to check for json -> currently json files without extension can't be required
            if /.json$/.test file.path
                source = "JSON.parse(#{JMin source})"
            # replace newlines with \n
            source = source.replace /\r\n|\n/g, '\\n'

            # html can have nested requireds: ${require('path/to/html')}
            if /.html$/.test file.path
                source = source.replace /\${\s*(require\s*\(\s*\d*?\s*\))\s*}/g, "' + $1 + '"
            code += "function(module, exports, require) {\r\nmodule.exports = #{source};\r\n},\r\n"
            @addSourceMap p, file, true

        p.code += code
        null








    #    00000000   00000000   0000000   0000000          00000000  000  000      00000000
    #    000   000  000       000   000  000   000        000       000  000      000     
    #    0000000    0000000   000000000  000   000        000000    000  000      0000000 
    #    000   000  000       000   000  000   000        000       000  000      000     
    #    000   000  00000000  000   000  0000000          000       000  0000000  00000000
    
    readFile: (path, parent) ->
        file = @fileMap[path]
        if file
            if parent
                parent.req[path]      = true
                file.ref[parent.path] = true
            return file

        file = @fileMap[path] =
            index:     @indexer.get path
            path:      path
            source:    ''
            sourceMap: ''
            numLines:  0
            ref:       {}
            req:       {}
            reqAsL:    {}
            error:     false

        if @cfg.watch
            @watcher.add path
            @watcher.add Path.dirname(path)

        if parent
            parent.req[path]      = true
            file.ref[parent.path] = true

        #console.log 'read file: ', path

        ++@openFiles
        FS.readFile path, 'utf8', (error, source) =>
            if error
                file.error = error
                @errors.push
                    path:  path
                    line:  -1
                    col:   -1
                    error: 'file read error'
            else
                file.error = null

                if /\.js$/.test path
                    # uglify
                    if @useUglify
                        source  = source.replace /process\.env\.NODE_ENV/g, 'NODE_ENV'
                        source  = source.replace /\r\n|\n/g, '\n'
                        map     = @getJson path + '.map'
                        @uglify = @uglify or require 'uglify-js'
                        try
                            result = @uglify.minify source,
                                mangle: false
                                sourceMap:
                                    content: map
                                    url:     Path.basename(path) + '.map'
                                compress:
                                    global_defs:
                                        'NODE_ENV': @NODE_ENV
                            #console.log 'UGLIFY: ', result.map
                        catch e
                            console.log 'ERROR while uglifying: ', path, e

                        if result
                            source = result.code
                            map    = JSON.parse result.map

                    #TODO: babel should be a compiler
                    # use babel if file is in node-modules and isn't an umd module and has an import statement
                    if @useBabel and /node_modules/.test(path) and not /\.umd\./.test(path) and /((^| )import )|((^| )class )|((^| )let )|((^| )const |((^| )export ))/gm.test(source)
                        Babel        = Babel or require 'babel-core'
                        Babel_es2015 = Babel_es2015 or require 'babel-preset-es2015'
                        babelOptions = babelOptions or
                            ast:     false
                            compact: false
                            presets: [Babel_es2015]
                        result = Babel.transform source, babelOptions
                        source = result.code
                        #console.log 'babel: transformed -> ' + Path.relative @cfg.base, path


                # handle source map
                if /.js$/.test path

                    mapPath    = path + '.map' #TODO: get map path from regex/source
                    source     = source.replace SINGLE_COMMENT_MAP, ''
                    source     = source.replace MULTI_COMMENT_MAP,  ''
                    numLines   = (source or '').split(/\r\n|\n/).length
                    fixFF      = @cfg.fffMaps
                    includeExt = @cfg.externalMaps

                    if @isFile(mapPath) and (path.indexOf(@out) == 0 or includeExt)
                        map            = map or @getJson(mapPath) or {}
                        file.sourceMap = map

                        # only touch sourcesContent to fix firefox sourcemap bug
                        if fixFF and map
                            map.sourcesContent = []

                            # include sources, if firefox fixing is enabled
                            for sourcePath, i in map.sources
                                absSourcePath = Path.resolve Path.dirname(file.path), map.sourceRoot or '', map.sources[0]
                                if fixFF and not map.sourcesContent[i]
                                    # add all original sources to the map to fix firefox sourcemap bug
                                    if @isFile(absSourcePath)
                                        map.sourcesContent.push FS.readFileSync(absSourcePath, 'utf8')
                                    else
                                        map.sourcesContent.push ''


                file.moduleId = Path.relative @out, path
                file.source   = source
                file.numLines = numLines
                @parseFile file

            @writePackages() if --@openFiles == 0
            null
        file




    #    00000000    0000000   00000000    0000000  00000000        00000000  000  000      00000000
    #    000   000  000   000  000   000  000       000             000       000  000      000     
    #    00000000   000000000  0000000    0000000   0000000         000000    000  000      0000000 
    #    000        000   000  000   000       000  000             000       000  000      000     
    #    000        000   000  000   000  0000000   00000000        000       000  0000000  00000000

    parseFile: (file) ->
        path   = file.path
        base   = Path.dirname path
        #regex  = /^([^\/]|(\/(?!\/)))*?require\s*\(\s*('|")(.*?)('|")\s*\)/gm
        regex  = /require\s*\(\s*('|")(.*?)('|")\s*\)/gm
        regPos = 2
        loaderRegex = new RegExp('^' + @cfg.loaderPrefix)

        #while result = regex.exec file.source
        file.source = file.source.replace regex, (args...) =>
            name     = @correctOut args[regPos]
            isLoader = loaderRegex.test name
            name     = name.replace loaderRegex, '' if isLoader

            if /\.|\//.test(name[0])
                modulePath = @getRelModulePath base, name
            else
                modulePath = @getNodeModulePath base, name

            if modulePath
                rfile = @readFile modulePath, file
                if isLoader
                    rpath      = rfile.path
                    loaderRefs = @loaders[rpath] or @loaders[rpath] = {}
                    loaderRefs[path]   = true
                    file.reqAsL[rpath] = true
                    # remove linking to enable chunks
                    delete file.req[rpath]
                    delete rfile.ref[path]

                    return "require(#{rfile.index}, '#{@getChunkPath rfile}')"
                return "require(#{rfile.index})"
            else
                if not @isComment file.source, args[4]
                    @errors.push
                        path:  path
                        line:  -1
                        col:   -1
                        error: 'packer.parseFile: module "' + name + '" not found'

            args[0]
        null




    #    000   0000000         0000000   0000000   00     00  00     00  00000000  000   000  000000000
    #    000  000             000       000   000  000   000  000   000  000       0000  000     000   
    #    000  0000000         000       000   000  000000000  000000000  0000000   000 0 000     000   
    #    000       000        000       000   000  000 0 000  000 0 000  000       000  0000     000   
    #    000  0000000          0000000   0000000   000   000  000   000  00000000  000   000     000   

    isComment: (text, index) ->
        sameLine      = true
        behindComment = false
        while --index > -1
            char1         = text[index]
            char2         = text[index + 1]
            chars         = char1 + char2
            sameLine      = sameLine and char1 != '\n'
            insideComment = chars == '/*'
            behindComment = chars == '*/'
            return true  if sameLine and chars == '//'
            return true  if insideComment
            return false if behindComment
        return false




    #    00000000   00000000  000            00     00   0000000   0000000    000   000  000      00000000
    #    000   000  000       000            000   000  000   000  000   000  000   000  000      000     
    #    0000000    0000000   000            000000000  000   000  000   000  000   000  000      0000000 
    #    000   000  000       000            000 0 000  000   000  000   000  000   000  000      000     
    #    000   000  00000000  0000000        000   000   0000000   0000000     0000000   0000000  00000000

    getRelModulePath: (base, moduleName) ->
        ext  = @testExt moduleName, 'js'
        path = Path.resolve base, moduleName
        return file if @isFile file = path + ext                                  # js file found
        return file if @isFile file = Path.join path, 'index.js'                  # index.js file found
        return path if ext and @isFile path                                       # asset file found
        null




    #    000   000   0000000   0000000    00000000        00     00   0000000   0000000    000   000  000      00000000
    #    0000  000  000   000  000   000  000             000   000  000   000  000   000  000   000  000      000     
    #    000 0 000  000   000  000   000  0000000         000000000  000   000  000   000  000   000  000      0000000 
    #    000  0000  000   000  000   000  000             000 0 000  000   000  000   000  000   000  000      000     
    #    000   000   0000000   0000000    00000000        000   000   0000000   0000000     0000000   0000000  00000000

    getNodeModulePath: (base, moduleName) ->
        nodePath   = Path.join base, 'node_modules'
        modulePath = Path.join nodePath, moduleName

        if @isDir nodePath
            ext = @testExt moduleName, 'js'
            return file if @isFile file = modulePath + ext                        # .js
            file = Path.join modulePath, 'package.json'                           # package.json
            try
                json = @getJson file
                main = json?.main
            catch
            if main
                ext = @testExt main, 'js'
                if @isFile file = Path.join modulePath, main + ext                # main
                    return file
            return file if @isFile file = Path.join modulePath, 'index.js'        # index.js
        if base and base != '/'             # abort, if outside project root
            return @getNodeModulePath Path.resolve(base, '..'), moduleName        # try next dir

        ### TODO: implement this???
        # try modules shipped with werkzeug
        if base != PROCESS_BASE
            return @getNodeModulePath PROCESS_BASE, moduleName
        ###
        null




    #     0000000   0000000   00     00  00000000   000      00000000  000000000  00000000  0000000  
    #    000       000   000  000   000  000   000  000      000          000     000       000   000
    #    000       000   000  000000000  00000000   000      0000000      000     0000000   000   000
    #    000       000   000  000 0 000  000        000      000          000     000       000   000
    #     0000000   0000000   000   000  000        0000000  00000000     000     00000000  0000000  

    completed: () ->
        if @errors.length
            for e in @errors
                console.log "ERROR in #{Path.relative @cfg.base, e.path}: #{e.error}"
        d = new Date()
        console.log "packer ready #{if @errors.length then 'with errors ' else '✓ '}(#{d.getHours()}:#{d.getMinutes()}:#{d.getSeconds()} #{d.getFullYear()}.#{d.getMonth()}.#{d.getDate()})"
        null




    #    000   000  00000000  000      00000000   00000000  00000000    0000000
    #    000   000  000       000      000   000  000       000   000  000     
    #    000000000  0000000   000      00000000   0000000   0000000    0000000 
    #    000   000  000       000      000        000       000   000       000
    #    000   000  00000000  0000000  000        00000000  000   000  0000000 

    testExt: (name, ext) ->
        return '' if new RegExp('\\' + ext + '$').test name
        '.' + ext


    isDir: (path) ->
        stat = @getStat(path)
        stat?.isDirectory() or false


    isFile: (path) ->
        stat = @getStat path
        stat?.isFile() or false


    getStat: (path) ->
        try
            stat = FS.statSync path
        stat


    getText: (path) ->
        try
            text = FS.readFileSync path, 'utf8'
        text


    getJson: (path) ->
        text = @getText path
        try
            json = JSON.parse text
        json


    correctOut: (path) ->
        return path.replace CSS_REG, '.css' if CSS_REG.test path
        return path.replace JS_REG,  '.js'  if JS_REG.test  path
        path


    isRequired: (file) ->
        Dict.hasKeys file.ref or @loaders[file.path]


    removeSources: (path) ->
        FS.unlinkSync path
        FS.unlinkSync path + '.map'
        null




module.exports = Packer