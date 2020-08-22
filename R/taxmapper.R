#' Maps an input taxonomy table onto a different taxonomic nomenclature.
#'
#' @author Dylan Catlett
#' @author Kevin Son
#'
#' @param tt The input taxonomy table you would like to map onto a new
#' taxonomic nomenclature. Should be a dataframe of type char (no factors).
#' @param tt.ranks A character vector of the column names where taxonomic
#' names are found in tt. Supply them heirarchically (e.g. kingdom --> species)
#' @param tax2map2 The taxonomic nomenclature you would like to map onto. pr2
#' v4.12.0 and Silva SSU v138 nr taxonomic nomenclatures are included in the
#' ensembleTax package. You can map to these by specifying "pr2" or "Silva".
#' Otherwise should be a dataframe of type character (no factors) with each
#' column corresponding to a taxonomic rank.
#' @param exceptions A character vector of taxonomic names at the basal/root
#' rank of tt that will be propagated onto the mapped taxonomy. ASVs assigned
#' to these names will retain these names at their basal/root rank in the mapped
#' taxonomy. All other ranks are assigned NA.
#' @param ignore.format If TRUE, the algorithm modifies taxonomic names to
#' account for common variations in taxonomic name syntax and/or formatting
#' commonly encountered in reference databases (e.g. Pseudonitzschia will map to
#' Pseudo-nitzschia). If FALSE, formatting issues may preclude mapping of
#' synonymous taxonomic names (e.g. Pseudonitzschia will NOT map to
#' Pseudo-nitzschia). An exhaustive list of formatting details is included in
#' Details.
#' @param synonym.file If "default", taxmapper uses taxonomic synonyms included
#' with the ensembleTax package. If a custom taxonomic synonym file is
#' preferred, a string corresponding to the name of the csv file should be
#' supplied. Taxonomic synonyms are searched when exact name matches are not
#' found in tax2map2. ignore.format does not apply to synonyms.
#' @param streamline If TRUE, only the mapped version of tt is returned as a
#' dataframe. If FALSE, a 3-element list is returned where element 1 is the
#' mapping rubric returned as a dataframe, element 2 is a character vector of
#' all names that could not be mapped (no exact matches found in tax2map2), and
#' element 3 is the mapped version of tt (a dataframe).
#' @param outfilez If NULL, mapping files are not saved to the current working
#' directory. Otherwise should be a 3-element character vector including, in
#' this order, the name of the file to store the taxonomic mapping key, the name
#' of the file to store the names that could not be mapped, and the name of the
#' file to store the ASVs supplied with tt with their mapped taxonomic
#' assignments. Each element of the vector should end in csv (only csv files
#' may be saved)
#'
#' @details Exceptions should be used when the user knows a particular taxonomic
#' group is not found in tax2map2. The user is responsible for supplying valid
#' taxonomic names as these must be found in tt and will be propagated as
#' given to all ASVs that are assigned this name in tt. This should only be
#' used for high-level taxonomic groups that are not found in a database (e.g.
#' for retaining Eukaryota when mapping onto a prokaryote-only taxonomic
#' nomenclature).
#'
#' When ignore.format = TRUE, taxmapper removes hyphens and underscores
#' from all elements of both tt and tax2map2. Each unique element separated
#' by a hyphen or underscore, in addition to a concatenated string with each
#' separate sub-string combined into one, is searched for exact matches. It also
#' removes case sensitivity of exact name-matching, and treats the following
#' taxonomic suffixes as equivalent: phyta, phytes, phyte, and phyceae.
#' ignore.format is never applied to synonym.file.
#'
#' For high-throughput implementation of taxmapper, it's recommended to set
#' streamline = TRUE.
#'
#' @seealso idtax2df, bayestax2df, LCA2df, ensembleTax, pr2_tax_miner,
#' silva_tax_miner
#'
#' @examples
#' fake.silva <- data.frame(ASV = c("AAAA", "ATCG", "GCGC", "TATA", "TCGA"),
#' domain = c("Bacteria", "Eukaryota", "Eukaryota", "Eukaryota", "Eukaryota"),
#' phylum = c("Firmicutes", "Diatomea", "Retaria", "MAST-12", "Diatomea"),
#' class = c(NA, "Coscinodiscophytina_cl", "Polycystinea", "MAST-12A",
#' "Mediophyceae"),
#' order = c(NA, "Fragilariales", "Collodaria", NA, NA),
#' family = c(NA, "Fragilariales_fa", "Collodaria_fa", NA, NA),
#' genus = c(NA, "Podocystis", "Collophidium", NA, NA),
#' stringsAsFactors = FALSE)
#' head(fake.silva)
#' mapped.silva <- taxmapper(fake.silva,
#'                           tt.ranks = colnames(fake.silva)[2:ncol(fake.silva)],
#'                           tax2map2 = "pr2",
#'                           exceptions = c("Archaea", "Bacteria"),
#'                           ignore.format = FALSE,
#'                           synonym.file = "default",
#'                           streamline = TRUE,
#'                           outfilez = NULL)
#'
#' @export
taxmapper <- function(tt,
                      tt.ranks = colnames(tt),
                      tax2map2 = "pr2",
                      exceptions = c("Archaea", "Bacteria"),
                      ignore.format = FALSE,
                      synonym.file = "default",
                      streamline = TRUE,
                      outfilez = NULL) {

  if (length(tt.ranks) == ncol(tt)) {
    stop("You have not included any ASV-identifying data in your input
         taxonomy table. Please do this and try again.")
  }

  if (tax2map2 == "pr2") {
    tax2map2 <- ensembleTax::pr2v4.12.0
  } else if (tax2map2 == "Silva") {
    tax2map2 <- ensembleTax::silva.nr.v138
  }
  tax2map2.ranks <- colnames(tax2map2)

  # function to create alternative terms with the suffix
  createAlts <- function(taxs) {
    result <- vector()
    for (tax in taxs) {
      a1 <- base::gsub("(phyta)", "phyceae", tax)
      a2 <- base::gsub("(phyta)", "phyte", tax)
      a3 <- base::gsub("(phyta)", "phytes", tax)
      a4 <- base::gsub("(phyceae)", "phyta", tax)
      a5 <- base::gsub("(phyceae)", "phyte", tax)
      a6 <- base::gsub("(phyceae)", "phytes", tax)
      a7 <- base::gsub("(phyte)", "phyta", tax)
      a8 <- base::gsub("(phyte)", "phyceae", tax)
      a9 <- base::gsub("(phyte)", "phytes", tax)
      a10 <- base::gsub("(phytes)", "phyta", tax)
      a11 <- base::gsub("(phytes)", "phyceae", tax)
      a12 <- base::gsub("(phytes)", "phyte", tax)
      result <- c(result, base::unique(c(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12)))
    }
    return(base::unique(result))
  }

  # function to remove hyphens, underscores, upper case of name
  preprocessTax <- function(taxonomy) {
    # split terms by hyphens
    no.hyphen <- base::strsplit(taxonomy, "-")
    # split terms by underscores
    no.underscore <- base::strsplit(taxonomy, "_")
    # split terms by first instance of underscores and combine previous splits
    taxs <- c(no.hyphen[[1]], no.underscore[[1]], base::gsub("(_.*)", "", taxonomy), taxonomy)
    # remove duplicates
    taxs <- base::unique(taxs)
    # convert all to lowercase
    no.upper <- base::tolower(taxs)
    # create alternative suffixes for certain taxonomies
    final.taxs <- createAlts(unique(c(taxs, no.upper)))
    return(final.taxs)
  }

  # function to search through the tax2map2 to find a match for the taxonomy name inputted
  findMapping <- function(taxonomy, tax2map2) {
    # iterate through the most specific ranking to the most generic ranking
    cols <- base::rev(names(tax2map2))
    for (i in 1:length(cols)) {
      matchings <- tax2map2[which(tax2map2[, cols[i]] == taxonomy), ] # find rows that match at that rank
      if (nrow(matchings) != 0) {
        # create respective row for the match
        # make everything downstream of the rank found to be NA's
        matched.row <- base::data.frame(matrix(rep(NA, length(cols)), ncol = length(cols), nrow = 1))
        colnames(matched.row) <- base::rev(cols)
        # grab only the first match found
        matched.row[1:(length(cols)-i+1)] <- matchings[1, ][1:(length(cols)-i+1)]
        return (matched.row)
      }
    }
    return(NA)
  }

  # function to search through the synonyms data frame to find synonyms for given taxonomy name
  getSynonyms <- function(taxonomy, syn.df) {
    found.rows <- syn.df[which(syn.df == taxonomy, arr.ind=TRUE)[,'row'],] # find rows for synonym
    if (length(found.rows) > 0) {
      # populate the taxonomy with its synonyms
      v <- as.character(as.matrix(found.rows))
      return (unique(c(taxonomy, v[!is.na(v)])))
    }
    else {
      # if no synonyms found, just return the taxonomy
      return (c(taxonomy))
    }
  }

  # rename tax2map2 columns for uniqueness
  colnames(tax2map2) <- base::paste("tax2map2", colnames(tax2map2), sep="_")

  # grab only the taxonomies part of the dataframes
  taxin.u <- base::unique(tt[, (names(tt) %in% tt.ranks)])
  tax2map2.u <- base::unique(tax2map2)

  # read in the synonyms file
  if (synonym.file != "default") {
    synonyms <- utils::read.csv(synonym.file)
    synonyms <- synonyms[, colnames(synonyms)[startsWith(colnames(synonyms), "Name")]]
  } else if (synonym.file == "default") {
    synonyms <- ensembleTax::synonyms_20200816
    synonyms <- synonyms[, colnames(synonyms)[startsWith(colnames(synonyms), "Name")]]
  }

  taxin.cols <- base::rev(names(taxin.u))

  # keep track of the taxonomy names that are not mapped
  not.mapped <- vector()

  # finialized mapping table from taxin to tax2map2 with only the taxonomy names
  mapped <- base::data.frame(matrix(ncol=(ncol(taxin.u) + ncol(tax2map2.u)),nrow=0, dimnames=list(NULL, c(names(taxin.u), names(tax2map2.u)))))

  # iterate through each row and column of taxin data frame
  for (row in 1:nrow(taxin.u)) {
    # keep track of the most generic taxonomy name
    highest.tax <- taxin.u[row, taxin.cols[ncol(taxin.u)]]
    # see if it is in the exceptions to skip the row
    if (base::is.element(highest.tax, exceptions)) {
      # create a NA row assignment since part of exceptions
      null.row <- base::data.frame(matrix(rep(NA, ncol(tax2map2.u)), ncol = ncol(tax2map2.u), nrow = 1, dimnames=list(NULL, names(tax2map2.u))))
      null.row[1] <- highest.tax
      combined <- base::cbind(taxin.u[row, ], null.row)
      mapped <- base::rbind(mapped, combined)
    }
    else {
      for (col in 1:ncol(taxin.u)) {
        # keep track of the original taxonomy name
        orig.tax <- taxin.u[row, taxin.cols[col]]
        # process the name to get alternatives by igorning its format
        if (ignore.format) {
          pos.taxs <- preprocessTax(orig.tax)
          for(tax in pos.taxs) {
            pos.taxs <- c(pos.taxs, getSynonyms(tax, synonyms))
          }
          pos.taxs <- base::unique(c(orig.tax, pos.taxs))
        }
        else {
          pos.taxs <- getSynonyms(orig.tax, synonyms)
        }
        # flag to keep track of when the row is already matched
        matched <- FALSE
        # counter to keep track what column number we are on
        counter <- 1
        # iterate through all alternatives of the taxonomy name with original one first
        for (taxonomy in pos.taxs) {
          last <- FALSE
          if (counter == length(pos.taxs)) {
            last <- TRUE
          }
          if (!is.na(taxonomy)) {
            # find matching
            match <- findMapping(taxonomy, tax2map2.u)
            if (is.data.frame(match)) {
              combined <- cbind(taxin.u[row, ], match)
              mapped <- rbind(mapped, combined)
              matched <- TRUE
              break
            }
            else { # if no matching is found, add to not.mapped
              if (last) {
                not.mapped <- c(not.mapped, orig.tax)
              }
            }
          }
          counter <- counter + 1
        }
        # if a match is found, we can move onto the next row
        if (matched) {
          break
        }
      }
    }
  }

  # use the mapped table created to left join the original data frame with metadata
  asv.mapped <- base::merge(x=tt, y=mapped, by=colnames(taxin.u), all.x=TRUE)
  asv.mapped <- asv.mapped[ , !(colnames(asv.mapped) %in% colnames(taxin.u))]
  # remove the unique addition of tax2map2 column names
  colnames(asv.mapped) <- base::gsub("tax2map2_", "", colnames(asv.mapped))

  # filter out duplicates for not mapped taxonomy names
  not.mapped <- base::unique(not.mapped)

  colnames(mapped) <- base::gsub("tax2map2_", "", colnames(mapped))

  zz <- base::apply(asv.mapped, MARGIN = 2, FUN = as.character)
  df <- base::as.data.frame(zz, stringsAsFactors = FALSE)
  asv.mapped <- df

  asv.mapped <- sort_my_taxtab(asv.mapped, ranknames = tax2map2.ranks)

  rownames(asv.mapped) <- NULL

  if (!(base::is.null(outfilez))) {
    utils::write.csv(mapped, outfilez[1], row.names=FALSE)
    not.mapped.df <- base::as.data.frame(not.mapped)
    utils::write.table(not.mapped.df, outfilez[2], row.names=FALSE, col.names=FALSE)
    utils::write.csv(asv.mapped, outfilez[3], row.names=FALSE)
  }

  if (streamline) {
    return(asv.mapped)
  } else {
    return (list(mapped, not.mapped, asv.mapped))
  }
}
