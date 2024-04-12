# Rubin Chart

This package is a library developed for work on the Vera C. Rubin Observatory Legacy Survey of Space Time (LSST) to assist in visualizing data taken by the Simonyi Survey Telescope.
For our analyses none of the existing open source flutter chart libraries that we found met all of our needs, as we require:

1. The ability to quickly display hundreds of thousands to millions of data points.
2. The ability to interact with those plots by panning, zooming, and interactively selecting and drilling down on plots that are connected together.
3. The ability to implement interactive legends that allow us to add and edit the series that are plotted in a chart.

The primary use of this library for us is to display information using the yet to be named https://github.com/lsst-ts/rubintv_visualization package, which connects to the telescope database and allows us to explore and drilldown on data.
So we recommend looking at that package to see how this library is used in the wild, although we have really customized that package for our particular use case.

We do hope that this can become a useful tool for others in the Flutter community, and our project as a whole is entirely open source, so please feel free to make changes and help us continue development.
