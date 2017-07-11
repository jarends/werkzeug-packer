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
- experimental uglifying 
     
  
### Usage  
  
```coffee-script

    # for global commandline use:
    npm install -g werkzeug-packer
    
    # or local to your project:
    npm install werkzeug-packer --save-dev
    
```
  
### Options  

```coffee-script
      
            
            
# If you specify more than the entry bundle, you have to require all other bundles 
# from your main file (or from subsequent required files).
# Otherwise they won't be activated.
# You also have to place src nodes for each bundle in your index.html             
```
  
  
### License  

werkzeug-packer is free and unencumbered public domain software. For more information, see http://unlicense.org/ or the accompanying UNLICENSE file.



   

