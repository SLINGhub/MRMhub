# Getting started with R and Quarto notebooks

Tutorial

A MRMhub analysis is written as a document that mixes prose with the R
code that produces the results, so the report and the analysis are one
file. This tutorial assumes no prior experience with R or Quarto: it
starts from an empty computer, installs the software, sets up the
project and notebook to work in, and shows how to read and run the code.
Once your machine is set up, [Getting started with
MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md)
runs a complete analysis in the project you create here.

## 1. Install R and an editor

Two pieces of software are needed. **R** is the language the analysis
runs in; an **integrated development environment** (IDE) is the editor
you write and run it in. Install R first — the IDE looks for it on
startup.

- Install R from [CRAN](https://cran.r-project.org/) (version 4.1 or
  newer). Pick the download for your operating system and accept the
  defaults.
- Install an IDE. [RStudio](https://posit.co/download/rstudio-desktop/)
  is the most common choice and the one this tutorial follows. If you
  already work in VS Code, [Positron](https://positron.posit.co/) is an
  RStudio-like alternative built on the same editor.

Both are installed once per machine and shared by every project you
create afterwards.

## 2. RStudio

When RStudio opens it shows four panes, each used at some point in an
analysis:

- **Source** (top-left) — where you edit the notebook and run its code.
  Its toolbar carries the **Render** button, and each code chunk gets a
  green ▶ arrow that runs it.
- **Console** (bottom-left) — runs a single line of R immediately,
  without saving it in the notebook. This is where software is installed
  and where MRMhub’s step messages appear.
- **Environment** (top-right) — lists the objects that currently exist
  in the session, such as the `mexp` data object once the notebook has
  created it.
- **Files / Plots / Help** (bottom-right) — browses the project folder,
  shows figures, and displays function help pages.

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA2NDAgNDcwIiBzdHlsZT0ibWF4LXdpZHRoOiA3MDBweDsgd2lkdGg6IDEwMCU7IGhlaWdodDogYXV0bzsgZm9udC1mYW1pbHk6IC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgJiMzOTtTZWdvZSBVSSYjMzk7LCBzYW5zLXNlcmlmOyIgcm9sZT0iaW1nIiBhcmlhLWxhYmVsPSJTY2hlbWF0aWMgb2YgdGhlIFJTdHVkaW8gd2luZG93OiB0aGUgU291cmNlIHBhbmUgdG9wLWxlZnQgaG9sZHMgdGhlIG5vdGVib29rIHdpdGggYW4gUiBjb2RlIGNodW5rLCBhIFJlbmRlciBidXR0b24gYW5kIGEgZ3JlZW4gcnVuIGFycm93OyB0aGUgQ29uc29sZSBib3R0b20tbGVmdCBydW5zIHNpbmdsZSBjb21tYW5kczsgdGhlIEVudmlyb25tZW50IHBhbmUgdG9wLXJpZ2h0IGxpc3RzIG9iamVjdHMgaW4gYSBuYW1lIGFuZCB2YWx1ZSB0YWJsZTsgdGhlIEZpbGVzIGFuZCBQbG90cyBwYW5lIGJvdHRvbS1yaWdodCBsaXN0cyB0aGUgcHJvamVjdCBmaWxlcy4iPjxyZWN0IHg9IjgiIHk9IjgiIHdpZHRoPSI2MjQiIGhlaWdodD0iNDI4IiByeD0iMTAiIGZpbGw9IiNmOGY5ZmEiIHN0cm9rZT0iIzJDM0U1MCIgc3Ryb2tlLXdpZHRoPSIyIiAvPjxjaXJjbGUgY3g9IjMwIiBjeT0iMjkiIHI9IjUiIGZpbGw9IiNkZWUyZTYiPjwvY2lyY2xlPjxjaXJjbGUgY3g9IjQ4IiBjeT0iMjkiIHI9IjUiIGZpbGw9IiNkZWUyZTYiPjwvY2lyY2xlPjxjaXJjbGUgY3g9IjY2IiBjeT0iMjkiIHI9IjUiIGZpbGw9IiNkZWUyZTYiPjwvY2lyY2xlPjx0ZXh0IHg9IjMyMCIgeT0iMzQiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI3MDAiIGZvbnQtc2l6ZT0iMTUiIGZpbGw9IiMyQzNFNTAiPm15X3N0dWR5CuKAlCBSU3R1ZGlvPC90ZXh0PjxsaW5lIHgxPSI4IiB5MT0iNDYiIHgyPSI2MzIiIHkyPSI0NiIgc3Ryb2tlPSIjZGVlMmU2Ij48L2xpbmU+PHJlY3QgeD0iMjAiIHk9IjU4IiB3aWR0aD0iMjkwIiBoZWlnaHQ9IjE5MCIgcng9IjYiIGZpbGw9IiNkNmU0ZWIiIHN0cm9rZT0iIzVCOEZBOCIgLz48cmVjdCB4PSIyMCIgeT0iNTgiIHdpZHRoPSIyOTAiIGhlaWdodD0iMjQiIHJ4PSI2IiBmaWxsPSIjZmZmZmZmIiBmaWxsLW9wYWNpdHk9IjAuNTUiIC8+PHRleHQgeD0iMzIiIHk9Ijc1IiBmb250LXNpemU9IjEwIiBmaWxsPSIjMkMzRTUwIj5hbmFseXNpcy5xbWQ8L3RleHQ+PHJlY3QgeD0iMjQwIiB5PSI2MiIgd2lkdGg9IjYyIiBoZWlnaHQ9IjE2IiByeD0iMyIgZmlsbD0iIzVCOEZBOCIgLz48dGV4dCB4PSIyNzEiIHk9Ijc0IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEwIiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjZmZmZmZmIj5SZW5kZXI8L3RleHQ+PHRleHQgeD0iMzIiIHk9IjEwNCIgZm9udC13ZWlnaHQ9IjYwMCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzJDM0U1MCI+U291cmNlPC90ZXh0Pjx0ZXh0IHg9IjI5MiIgeT0iMTA1IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEzIiBmaWxsPSIjNkI5RTVFIj7ilrY8L3RleHQ+PHRleHQgeD0iMzIiIHk9IjEyNCIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyI+ZWRpdCBwcm9zZSBhbmQgY29kZQpjaHVua3MgaGVyZTwvdGV4dD48cmVjdCB4PSIzMiIgeT0iMTM2IiB3aWR0aD0iMjUyIiBoZWlnaHQ9IjY2IiByeD0iNCIgZmlsbD0iI2ZmZmZmZiIgZmlsbC1vcGFjaXR5PSIwLjgiIHN0cm9rZT0iI2E5YzZkNCIgLz48dGV4dCB4PSI0MiIgeT0iMTU0IiBmb250LXNpemU9IjEwLjUiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIiBmaWxsPSIjN2E4Yjk0Ij5gYGB7cn08L3RleHQ+PHRleHQgeD0iNDIiIHk9IjE3NCIgZm9udC1zaXplPSIxMC41IiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLCBNZW5sbywgQ29uc29sYXMsIG1vbm9zcGFjZSIgZmlsbD0iIzMxNTg2YiI+bWV4cAombHQ7LSBub3JtYWxpemVfYnlfaXN0ZChtZXhwKTwvdGV4dD48dGV4dCB4PSI0MiIgeT0iMTk0IiBmb250LXNpemU9IjEwLjUiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIiBmaWxsPSIjN2E4Yjk0Ij5gYGA8L3RleHQ+PHRleHQgeD0iMzIiIHk9IjIyOCIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyI+4pa2IHJ1bnMgYSBjaHVuaywgUmVuZGVyCmJ1aWxkcyB0aGUgcmVwb3J0PC90ZXh0PjxyZWN0IHg9IjMyNiIgeT0iNTgiIHdpZHRoPSIyOTQiIGhlaWdodD0iMTkwIiByeD0iNiIgZmlsbD0iI2RjZWZlOSIgc3Ryb2tlPSIjNmNhYjliIiAvPjx0ZXh0IHg9IjMzOCIgeT0iODYiIGZvbnQtd2VpZ2h0PSI2MDAiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiMyQzNFNTAiPkVudmlyb25tZW50PC90ZXh0Pjx0ZXh0IHg9IjMzOCIgeT0iMTEwIiBmb250LXNpemU9IjkuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzdhOGI5NCI+TmFtZTwvdGV4dD48dGV4dCB4PSI0NTIiIHk9IjExMCIgZm9udC1zaXplPSI5LjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiM3YThiOTQiPlZhbHVlPC90ZXh0PjxsaW5lIHgxPSIzMzgiIHkxPSIxMTciIHgyPSI2MDgiIHkyPSIxMTciIHN0cm9rZT0iI2M0ZDhkMiI+PC9saW5lPjx0ZXh0IHg9IjMzOCIgeT0iMTM2IiBmb250LXNpemU9IjEwLjUiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIiBmaWxsPSIjMmY2ZjYzIj5tZXhwPC90ZXh0Pjx0ZXh0IHg9IjQ1MiIgeT0iMTM2IiBmb250LXNpemU9IjEwLjUiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIiBmaWxsPSIjM2Q0NzUwIj5NUk1odWJFeHBlcmltZW50PC90ZXh0PjxsaW5lIHgxPSIzMzgiIHkxPSIxNDMiIHgyPSI2MDgiIHkyPSIxNDMiIHN0cm9rZT0iI2RjZWNlOCI+PC9saW5lPjx0ZXh0IHg9IjMzOCIgeT0iMTU4IiBmb250LXNpemU9IjEwLjUiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIiBmaWxsPSIjMmY2ZjYzIj5kX2NvbmM8L3RleHQ+PHRleHQgeD0iNDUyIiB5PSIxNTgiIGZvbnQtc2l6ZT0iMTAuNSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSwgTWVubG8sIENvbnNvbGFzLCBtb25vc3BhY2UiIGZpbGw9IiMzZDQ3NTAiPjg0Cm9icy4gb2YgMTIgdmFyaWFibGVzPC90ZXh0PjxsaW5lIHgxPSIzMzgiIHkxPSIxNjUiIHgyPSI2MDgiIHkyPSIxNjUiIHN0cm9rZT0iI2RjZWNlOCI+PC9saW5lPjx0ZXh0IHg9IjMzOCIgeT0iMTgwIiBmb250LXNpemU9IjEwLjUiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIiBmaWxsPSIjMmY2ZjYzIj5uX2ZlYXR1cmVzPC90ZXh0Pjx0ZXh0IHg9IjQ1MiIgeT0iMTgwIiBmb250LXNpemU9IjEwLjUiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIiBmaWxsPSIjM2Q0NzUwIj5pbnQKODQ8L3RleHQ+PHRleHQgeD0iMzM4IiB5PSIyMTQiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiMzMzMiPnRoZSBvYmplY3RzCnRoYXQgZXhpc3QgcmlnaHQgbm93LDwvdGV4dD48dGV4dCB4PSIzMzgiIHk9IjIzMiIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyI+ZW1wdHkgYWdhaW4gaW4gYSBmcmVzaApzZXNzaW9uPC90ZXh0PjxyZWN0IHg9IjIwIiB5PSIyNTgiIHdpZHRoPSIyOTAiIGhlaWdodD0iMTcwIiByeD0iNiIgZmlsbD0iI2ZmZmZmZiIgc3Ryb2tlPSIjZGVlMmU2IiAvPjx0ZXh0IHg9IjMyIiB5PSIyODYiIGZvbnQtd2VpZ2h0PSI2MDAiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiMyQzNFNTAiPkNvbnNvbGU8L3RleHQ+PHRleHQgeD0iMzIiIHk9IjMxMiIgZm9udC1zaXplPSIxMC41IiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLCBNZW5sbywgQ29uc29sYXMsIG1vbm9zcGFjZSIgZmlsbD0iIzRhNTU2MCI+Jmd0OwpwYWs6OnBhaygmcXVvdDtTTElOR2h1Yi9NUk1odWImcXVvdDspPC90ZXh0Pjx0ZXh0IHg9IjMyIiB5PSIzMzIiIGZvbnQtc2l6ZT0iMTAuNSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSwgTWVubG8sIENvbnNvbGFzLCBtb25vc3BhY2UiIGZpbGw9IiM0YTU1NjAiPiZndDsKbXJtaHViOjpidWlsZF93b3JrZmxvdygpPC90ZXh0Pjx0ZXh0IHg9IjMyIiB5PSIzNTIiIGZvbnQtc2l6ZT0iMTAuNSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSwgTWVubG8sIENvbnNvbGFzLCBtb25vc3BhY2UiIGZpbGw9IiMzYTVmMzAiPuKclApOb3JtYWxpemVkIDg0IGZlYXR1cmVzIGJ5IElTVEQ8L3RleHQ+PHRleHQgeD0iMzIiIHk9IjM4NCIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyI+cnVucyBhIHNpbmdsZSBsaW5lIG9mIFIKaW1tZWRpYXRlbHk7PC90ZXh0Pjx0ZXh0IHg9IjMyIiB5PSI0MDQiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiMzMzMiPk1STWh1YuKAmXMgc3RlcCBtZXNzYWdlcwphcnJpdmUgaGVyZTwvdGV4dD48cmVjdCB4PSIzMjYiIHk9IjI1OCIgd2lkdGg9IjI5NCIgaGVpZ2h0PSIxNzAiIHJ4PSI2IiBmaWxsPSIjZjRmNmY3IiBzdHJva2U9IiNjNWNiZDAiIC8+PHRleHQgeD0iMzM4IiB5PSIyODYiIGZvbnQtd2VpZ2h0PSI2MDAiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiMyQzNFNTAiPkZpbGVzCiZhbXA7IFBsb3RzPC90ZXh0Pjx0ZXh0IHg9IjMzOCIgeT0iMzA4IiBmb250LXNpemU9IjEwIiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLCBNZW5sbywgQ29uc29sYXMsIG1vbm9zcGFjZSIgZmlsbD0iIzdhOGI5NCI+bXlfc3R1ZHkvPC90ZXh0PjxyZWN0IHg9IjM0MCIgeT0iMzE4LjUiIHdpZHRoPSI2IiBoZWlnaHQ9IjMiIHJ4PSIxIiBmaWxsPSIjOGZhOGI4IiAvPjxyZWN0IHg9IjM0MCIgeT0iMzIxIiB3aWR0aD0iMTQiIGhlaWdodD0iOS41IiByeD0iMS41IiBmaWxsPSIjOGZhOGI4IiAvPjx0ZXh0IHg9IjM2MiIgeT0iMzMwIiBmb250LXNpemU9IjEwLjUiIGZvbnQtZmFtaWx5PSJ1aS1tb25vc3BhY2UsIE1lbmxvLCBDb25zb2xhcywgbW9ub3NwYWNlIiBmaWxsPSIjM2Q0NzUwIj5kYXRhLzwvdGV4dD48cmVjdCB4PSIzNDAiIHk9IjM0MC41IiB3aWR0aD0iNiIgaGVpZ2h0PSIzIiByeD0iMSIgZmlsbD0iIzhmYThiOCIgLz48cmVjdCB4PSIzNDAiIHk9IjM0MyIgd2lkdGg9IjE0IiBoZWlnaHQ9IjkuNSIgcng9IjEuNSIgZmlsbD0iIzhmYThiOCIgLz48dGV4dCB4PSIzNjIiIHk9IjM1MiIgZm9udC1zaXplPSIxMC41IiBmb250LWZhbWlseT0idWktbW9ub3NwYWNlLCBNZW5sbywgQ29uc29sYXMsIG1vbm9zcGFjZSIgZmlsbD0iIzNkNDc1MCI+b3V0cHV0LzwvdGV4dD48cmVjdCB4PSIzNDEuNSIgeT0iMzY0IiB3aWR0aD0iMTEiIGhlaWdodD0iMTIiIHJ4PSIxLjUiIGZpbGw9IiNjM2M5Y2UiIC8+PHRleHQgeD0iMzYyIiB5PSIzNzQiIGZvbnQtc2l6ZT0iMTAuNSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSwgTWVubG8sIENvbnNvbGFzLCBtb25vc3BhY2UiIGZpbGw9IiMzZDQ3NTAiPmFuYWx5c2lzLnFtZDwvdGV4dD48cmVjdCB4PSIzNDEuNSIgeT0iMzg2IiB3aWR0aD0iMTEiIGhlaWdodD0iMTIiIHJ4PSIxLjUiIGZpbGw9IiNjM2M5Y2UiIC8+PHRleHQgeD0iMzYyIiB5PSIzOTYiIGZvbnQtc2l6ZT0iMTAuNSIgZm9udC1mYW1pbHk9InVpLW1vbm9zcGFjZSwgTWVubG8sIENvbnNvbGFzLCBtb25vc3BhY2UiIGZpbGw9IiMzZDQ3NTAiPm15X3N0dWR5LlJwcm9qPC90ZXh0Pjx0ZXh0IHg9IjMzOCIgeT0iNDE4IiBmb250LXNpemU9IjEwLjUiIGZpbGw9IiMzMzMiPmZpZ3VyZXMgb3BlbiBpbgpQbG90cywgaGVscCBwYWdlcyBpbiBIZWxwPC90ZXh0Pjx0ZXh0IHg9IjMyMCIgeT0iNDU4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjExIiBmaWxsPSIjNjY2Ij5SU3R1ZGlv4oCZcwpkZWZhdWx0IGZvdXItcGFuZSBsYXlvdXQsIHdpdGggdGhlIHByb2plY3QgZm9sZGVyIG9wZW4gYXMKbXlfc3R1ZHk8L3RleHQ+PC9zdmc+)

The panes can be resized or rearranged, but the defaults are fine to
start; nothing here needs configuring.

## 3. Install MRMhub

With R and RStudio installed, open RStudio and install MRMhub from the
Console (the bottom-left pane). The first line installs `pak`, a package
installer; the second uses it to fetch MRMhub and its dependencies:

``` r

if (!require("pak")) install.packages("pak")
pak::pak("SLINGhub/MRMhub")
```

Installing is a once-per-machine step, and running the same two lines
again later updates MRMhub to the current version. Making its functions
available is a separate, per-session step —
[`library(mrmhub)`](https://github.com/SLINGhub/MRMhub) — which belongs
in the notebook rather than the Console, so that every render loads the
package itself.

If the installation reports an error, the [Installation
guide](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md)
lists the common causes (a missing compiler on Windows or macOS, a
firewall blocking the download) and their fixes.

## 4. Create a Quarto project

A **project** keeps everything for one analysis — data, code, and
results — in a single folder that the IDE treats as a unit. In RStudio,
choose *File → New Project → New Directory → Quarto Project*, give it a
name, and create it. Quarto itself ships with RStudio, so nothing
further needs installing; if the *Quarto Project* entry is missing,
update RStudio or install Quarto from
[quarto.org](https://quarto.org/docs/download/). Quarto’s [project
documentation](https://quarto.org/docs/tools/rstudio/) covers the dialog
in detail.

The dialog creates the folder, a first `.qmd` document, and an `.Rproj`
file. That `.Rproj` file is how the project is reopened later — by
double-clicking it, or through the project menu at the top-right of the
RStudio window. Opening the project, rather than the `.qmd` on its own,
is what points R at the right folder.

Inside the new project, add two folders to keep raw inputs separate from
generated results — the convention MRMhub’s own workflows follow:

    my_study/
    ├── my_study.Rproj   # opens the project
    ├── data/            # raw INTEGRATOR output and metadata files
    ├── output/          # exported CSVs, PDFs, and reports
    └── analysis.qmd     # this document

Paths in your code are written relative to this project folder: RStudio
treats it as the working directory, so `data/my_file.csv` points to the
same place on any machine, without a full path. This is why the `data/`
and `output/` folders above are all the analysis needs to find its
files, and why the whole folder can be zipped and shared as a
self-contained unit.

## 5. Write text and code in a `.qmd`

A `.qmd` file is plain text with three kinds of content: a header,
prose, and code chunks.

At the top, a short **header** fenced by `---` sets the title and the
output format — `html`, `pdf`, or `docx`. A new project starts with a
sensible HTML header, and [Quarto
workflows](https://slinghub.github.io/MRMhub/quant/articles/manual-11-quarto-workflows.md)
covers the options that matter for a MRMhub report.

Below the header, **prose** is written in Markdown — plain paragraphs,
with `#` for headings, `**bold**`, and `-` for lists. Quarto’s [Markdown
basics](https://quarto.org/docs/authoring/markdown-basics.html) is the
full reference for tables, figures, cross-references, and citations.

**Code** lives in *chunks*: R code fenced between ```` ```{r} ```` and
```` ``` ````. In RStudio, *Insert → Code Chunk* (or Ctrl/Cmd + Alt + I)
adds an empty one. A chunk that loads the MRMhub package, with a
sentence of prose introducing it, looks like this:

```` markdown
Load the package before calling any of its functions.

```{r}
library(mrmhub)
```
````

### Chunk options

Each chunk can carry **options** that control whether its code runs,
whether the code itself is shown, and which parts of its output reach
the report. They are written as `#|` comment lines directly below the
chunk’s opening fence, one per line, as `option: value`:

```` markdown
```{r}
#| label: normalize
#| message: true
mexp <- normalize_by_istd(mexp)
```
````

The options a processing notebook needs are few:

| Option | What it controls |
|----|----|
| `#| label:` | A unique name for the chunk; also names any figure it produces. |
| `#| eval:` | Whether the code runs. `false` shows the code without executing it. |
| `#| echo:` | Whether the code itself appears in the report. |
| `#| output:` | Whether the results appear — printed values, tables, figures. |
| `#| message:` | Whether messages appear. MRMhub’s step feedback travels here. |
| `#| warning:` | Whether warnings appear. |
| `#| include:` | `false` runs the chunk but hides both code and output — used for setup chunks. |
| `#| cache:` | Stores the result, so an unchanged chunk is not re-run on the next render. |
| `#| fig-width:`, `#| fig-height:` | Size, in inches, of the figures the chunk produces. |

MRMhub reports what each processing step did as a console message — a
count, and a truncated list of the features or analyses affected — so
keeping `#| message: true` on the chunks that run a step turns the
rendered report into a record of the processing. Defaults for the whole
document are set in the header instead of chunk by chunk:

``` yaml
execute:
  warning: true
  message: true
```

Quarto’s [execution
options](https://quarto.org/docs/computations/execution-options.html)
page is the complete reference for both forms.

RStudio offers two ways to edit a `.qmd`: the **Source** editor shows
the raw Markdown, while the **Visual** editor (the *Visual* toggle,
top-left of the document) shows a formatted, word-processor-like view.
Both edit the same file, and Quarto’s [authoring
guide](https://quarto.org/docs/get-started/hello/rstudio.html)
introduces both. You may also meet the older R Markdown format (`.Rmd`),
which Quarto renders unchanged; it writes the same options inside the
fence, as `{r, message=TRUE}`.

## 6. Run code and render the report

There are two distinct actions. **Running a chunk** executes its code
immediately and shows the result inline: click the green ▶ arrow at the
chunk’s top-right, or press Ctrl/Cmd + Shift + Enter with the cursor
inside it. Because each chunk builds on the objects the earlier ones
created, *Run → Run All Chunks Above* (Ctrl/Cmd + Alt + P) is the way
back to a working state after reopening the project, when the session
starts with an empty Environment.

**Rendering** turns the whole document into a finished report: click
**Render** (Ctrl/Cmd + Shift + K), and Quarto runs every chunk in order
and assembles the output — `analysis.html` alongside the document —
which opens in the Preview pane and refreshes on each render.

Rendering runs in a **fresh R session**, top to bottom, so the report is
built from what the document itself contains and nothing else. A chunk
that works interactively because a needed object is still in the
Environment pane will fail on render if no chunk creates it. This is the
point of rendering: it proves the analysis reproduces from the raw data.
While developing, run chunks one at a time to check each step; render at
the end to produce the shareable report.

Try it now: insert a chunk into your document, put
[`library(mrmhub)`](https://github.com/SLINGhub/MRMhub) in it, and run
it. Loading MRMhub without error confirms the installation worked.

``` r

library(mrmhub)
```

If a chunk stops with an error, the Console prints the message under the
offending call; the last line is usually the informative one.
[Troubleshooting &
FAQ](https://slinghub.github.io/MRMhub/quant/articles/manual-10-troubleshooting.md)
collects the errors that come up most often, and what each one means.

## 7. Reading the code you’ll run

The next tutorial uses MRMhub functions and no custom R, but three
pieces of R syntax recur throughout. Recognising them is enough to
follow along:

- **Assignment** (`<-`) stores a result under a name.
  `mexp <- MRMhubExperiment()` creates a data object and names it
  `mexp`; writing `mexp` again later refers back to it.
- **Function calls with named arguments.** In
  `import_data_mrmhub(mexp, path = demo_file)`, the function acts on
  `mexp`, and `path =` names which input the file is. Most MRMhub
  functions take the data object first and options as named arguments.
- **The pipe** (`|>`) passes a result straight into the next function,
  so `plot_pca(mexp) |> save_plot("pca.pdf")` plots and then saves in
  one line, with no temporary name.

Each processing step follows the same shape — take the data object,
return an updated one, and store it back under the same name:
`mexp <- normalize_by_istd(mexp)`. The functions do not modify the
object in place, so the assignment is what carries the result forward;
running `normalize_by_istd(mexp)` on its own leaves `mexp` as it was.
All the documentation names the object `mexp`, and keeping that one name
throughout a notebook avoids running a later step on an earlier version
of the data.

## 8. Getting help

To see what a function does and which arguments it takes, type `?`
followed by its name in the Console:

``` r

?plot_pca
```

Its help page opens in the **Help** pane, listing every argument with an
explanation and, usually, examples that can be copied and run. The same
pages for every function are in the [function
reference](https://slinghub.github.io/MRMhub/quant/reference/index.md),
the [MRMhub
overview](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md)
introduces the concepts they build on, and problems that look like a bug
belong in the [issue
tracker](https://github.com/SLINGhub/MRMhub/issues).

The editor and the notebook format are documented by their own projects:

- [RStudio user guide:
  panes](https://docs.posit.co/ide/user/ide/guide/ui/ui-panes.html):
  Posit’s reference for the four panes, including how to resize and
  rearrange them
- [Hello,
  Quarto](https://quarto.org/docs/get-started/hello/rstudio.html):
  Quarto’s own walkthrough of writing and rendering a `.qmd` in RStudio

With the software installed, the project set up, and the syntax
demystified, you are ready to run a real analysis. Continue with
[Getting started with
MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md),
which imports the demo data and takes it through to an exported report.

## Next steps

- [Getting started with
  MRMhub](https://slinghub.github.io/MRMhub/quant/articles/tutorial-02-getting-started-mrmhub.md):
  run a complete analysis in the project you just created
- [Quarto
  workflows](https://slinghub.github.io/MRMhub/quant/articles/manual-11-quarto-workflows.md):
  rendering, figure sizing, and report options
- [Installation
  guide](https://slinghub.github.io/MRMhub/quant/articles/manual-00-installation.md):
  detailed setup and troubleshooting
