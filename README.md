# werkzeug-packer  

Packs commonjs modules to browser ready bundles.  
It is limited in its skills but easy to use and fast.  
  
What werkzeug-packer does:   
- packs your commonjs style modules to bundles for use in browsers
- supports asynchronous chunks (webpack style promisses)
- watches for changes and packs incremental
- merges source maps for all files into one for each bundle (with the ability to inline sources for use in firefox)
- you can require json, css, html and txt files in your code, which will be inlined as strings (except json, which exports an object)  
- has little support for es6 node modules (es6 will be transpiled using babel)
- experimental uglifying (leads to incorrect source mappings)
     
  
### Usage  
  
```text

    # for global commandline use:
    npm install -g werkzeug-packer
    
    # or local to your project:
    npm install werkzeug-packer --save-dev
    
    # if you have a file main.js, type:
    wzp -p main.js
    
    # this will create a bundle main.pack.js which includes all required files
    
    # you also can specify the name and location for the resulting bundle
    wzp -p main.js ./dist/main.bundle.js
    
    # you can pack any number of modules:
    wzp -p main.js -p vendor.js -p polyfills.js
    
    # you have to add script tags for all packs 
    # to your index.html in the same order as specified  
    
    # add a -w flag to watch
    wzp -p main.js -w
    
```
  
### Flags  
werkzeug-packer can be configured with the following flags:

```text
    
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
-v  --version                       Prints the version.
-h  --help                          Prints this help.  
            
            
If you specify more than the entry bundle, you have to require all other bundles from your main file (or from subsequent required files).
Otherwise they won't be activated.
Remember to place script tags for each bundle in your index.html.   
           
```

### Chunks

```coffee-script

    # consider a file test.js
    module.exports = Hello: 'World'
    
    # then you can do the following in another file:
    test = require 'es6-promise!./test'
    test('Hello').then (result) ->
        console.log 'Hello ' + result # prints 'Hello World' ;-)
              
    # if the name is omitted the whole exports object is passed to result              
    
```
   
  
### License  

werkzeug-packer is free and unencumbered public domain software. For more information, see http://unlicense.org/ or the accompanying UNLICENSE file.



   

