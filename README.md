# jekyll-graphs

## Installation

Install the required renderers with your favourite package manager, e.g. on Ubuntu: `$ [sudo] apt-get install graphviz mscgen`, and place the `jekyll-graphs.rb` plugin in your sites `_plugins` directory.

## Usage

jekyll-graphs can be used in several ways, the most explicit way is to use liquid `{% renderer %}` blocks such as:

### Liquid tags

Liquid `{% *renderer* %}` blocks, where renderer is the name of the renderer, can be used wherever liquid is rendered.

    {% *renderer* %}
    /----+  DAAP /-----+-----+ Audio  /--------+
    | PC |<------| RPi | MPD |------->| Stereo |
    +----+       +-----+-----+        +--------+
       |                 ^ ^
       |     ncmpcpp     | | mpdroid /---------+
       +--------=--------+ +----=----| Nexus S |
                                     +---------+
    {% end*renderer* %}

### Pages with _file tags

jekyll-graphs will also process pages specified in `{% *renderer*_file *file* %}` tags.

    ---
    permalink: /some/path/image.png
    ---
    
    /----+  DAAP /-----+-----+ Audio  /--------+
    | PC |<------| RPi | MPD |------->| Stereo |
    +----+       +-----+-----+        +--------+
       |                 ^ ^
       |     ncmpcpp     | | mpdroid /---------+
       +--------=--------+ +----=----| Nexus S |
                                     +---------+

### Code blocks

The final way in which jekyll-graphs can be used is with code blocks when using the kramdown parser. For example:

        /----+  DAAP /-----+-----+ Audio  /--------+
        | PC |<------| RPi | MPD |------->| Stereo |
        +----+       +-----+-----+        +--------+
           |                 ^ ^
           |     ncmpcpp     | | mpdroid /---------+
           +--------=--------+ +----=----| Nexus S |
                                         +---------+
    {: *renderer*="*renderer*" }

This is the suggested method as it degrades the most gracefully outputting the source in `<pre><code>...</code></pre>` tags.

### Options

jekyll-graphs allows all the following options to be specified:

    encoding
        The encoding to use when proccessing the graphs. Defaults to the site encoding or utf-8.
    
    renderer
        The desired renderer. From the following lists:
            graphviz: dot neato twopi circo fdp sfdp patchwork
            tex: tex latex pdftex pdflatex xetex xelatex luatex lualatex
            others: mscgen plantuml shaape
    
    format
        The output format of the svg. Supported values:
            img: <img src="...svg" alt="..." title="...">
            object: <object data="...svg" type="image/svg+xml"><a href="...svg">...</a></object>
            embed: <embed src="...svg" type="image/svg+xml" />
            iframe: <iframe src="...svg" sandbox="allow-scripts"></iframe>
            url, uri, href: ...svg
            svg: <svg ...>...</svg>
        
        Defaults to svg.

The liquid block and kramdown code block methods also permit the following extra options to be specified:

    dirname
        The output path of the rendered image. This may contain %{hash} which
        will be replaced by a hexadecimal string unquie to the image, and %{slug}
        which will be replaced with a slug either generated from the graph or
        the name of the renderer.
    
    name
        The output filename of the rendered image. This may contain %{hash}
        which will be replaced by a hexadecimal string unquie to the image, and %{slug}
        which will be replaced with a slug either generated from the graph or
        the name of the renderer.

The following global-only option may be specified:

    renderers
        It is a hash of key-values, with renderer names specified as keys and paths or
        arguments specified as values. If a string is provided, it is expected to be the
        path to the executable. If an array is provided, the first item will be treated as
        the path to an executable and the remaining items as command line arguments.
        
        The command line arguments for PlantUML must be specified to use it. They should be
        provided as [java, -jar, /path/to/plantuml.8021.jar].

#### Global Configuration

Global options may be set in your sites `_config.yml` file under the `jgraphs:` key. For example:

    jgraphs:
      dirname: /assets/images/
      format: object
      renderers:
        plantuml: [java, -jar, ~/plantuml.8021.jar]

#### Defaults

The following defaults are enforced:

    :encoding => "utf-8",
    :renderer => "dot",
    :scale => 1.0

## Acknowledgements

[Graphviz](http://graphviz.org/) was developed by [AT&T Labs Research](http://www.att.com/labs/) and other contributors.

[TeX](https://www.tug.org/) was created by [Donald Knuth](https://cs.stanford.edu/~uno/) and others.

[LaTeX](http://latex-project.org/) was created by [Leslie Lamport](http://www.lamport.org/) and others.

[pdfTeX](https://www.tug.org/applications/pdftex/) was created by [Hàn Thế Thành](hanthethanh@gmail.com) and others.

[XeTeX](http://xetex.sourceforge.net/) was created by Jonathan Kew and is developed by Khaled Hosny and others.

[LuaTeX](http://www.luatex.org/) was created by Taco Hoekwater, Hartmut Henkel and Hans Hagen.

[Mscgen](http://www.mcternan.me.uk/mscgen/) was created by [Michael McTernan](http://www.mcternan.me.uk/).

[PlantUML](http://plantuml.com/) was created by Arnaud Roques.

[Shaape](https://github.com/christiangoltz/shaape) was created by [Christian Goltz](https://github.com/christiangoltz).

## License

See [LICENSE](https://github.com/tmthrgd/ditaa-ditaa/blob/master/LICENSE).