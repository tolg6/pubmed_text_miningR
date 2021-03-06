xml_to_frame <- function(file) {
  library(XML)
  newData <- xmlParse(file)
  records <- getNodeSet(newData, "//PubmedArticle")
  pmid <- xpathSApply(newData,"//MedlineCitation/PMID", xmlValue)
  doi <- lapply(records, xpathSApply, ".//ELocationID[@EIdType = \"doi\"]", xmlValue)
  doi[sapply(doi, is.list)] <- NA
  doi <- unlist(doi)
  authLast <- lapply(records, xpathSApply, ".//Author/LastName", xmlValue)
  authLast[sapply(authLast, is.list)] <- NA
  authInit <- lapply(records, xpathSApply, ".//Author/Initials", xmlValue)
  authInit[sapply(authInit, is.list)] <- NA
  authors <- mapply(paste, authLast, authInit, collapse = "|")
  ## affiliations <- lapply(records, xpathSApply, ".//Author/AffiliationInfo/Affiliation", xmlValue)
  ## affiliations[sapply(affiliations, is.list)] <- NA
  ## affiliations <- sapply(affiliations, paste, collapse = "|")
  year <- lapply(records, xpathSApply, ".//PubDate/Year", xmlValue) 
  year[sapply(year, is.list)] <- NA
  year[which(sapply(year, is.na) == TRUE)] <- lapply(records[which(sapply(year, is.na) == TRUE)], xpathSApply, ".//PubDate/MedlineDate", xmlValue)
  year <- gsub(" .+", "", year)
  year <- gsub("-.+", "", year)
  articletitle <- lapply(records, xpathSApply, ".//ArticleTitle", xmlValue) 
  articletitle[sapply(articletitle, is.list)] <- NA
  articletitle <- unlist(articletitle)
  journal <- lapply(records, xpathSApply, ".//ISOAbbreviation", xmlValue) 
  journal[sapply(journal, is.list)] <- NA
  journal <- unlist(journal)
  volume <- lapply(records, xpathSApply, ".//JournalIssue/Volume", xmlValue)
  volume[sapply(volume, is.list)] <- NA
  volume <- unlist(volume)
  issue <- lapply(records, xpathSApply, ".//JournalIssue/Issue", xmlValue)
  issue[sapply(issue, is.list)] <- NA
  issue <- unlist(issue)
  pages <- lapply(records, xpathSApply, ".//MedlinePgn", xmlValue)
  pages[sapply(pages, is.list)] <- NA
  pages <- unlist(pages)
  abstract <- lapply(records, xpathSApply, ".//Abstract/AbstractText", xmlValue)
  abstract[sapply(abstract, is.list)] <- NA
  abstract <- sapply(abstract, paste, collapse = "|")
  meshHeadings <- lapply(records, xpathSApply, ".//DescriptorName", xmlValue)
  meshHeadings[sapply(meshHeadings, is.list)] <- NA
  meshHeadings <- sapply(meshHeadings, paste, collapse = "|")
  chemNames <- lapply(records, xpathSApply, ".//NameOfSubstance", xmlValue)
  chemNames[sapply(chemNames, is.list)] <- NA
  chemNames <- sapply(chemNames, paste, collapse = "|")
  grantAgency <- lapply(records, xpathSApply, ".//Grant/Agency", xmlValue)
  grantAgency[sapply(grantAgency, is.list)] <- NA
  grantAgency <- sapply(grantAgency, paste, collapse = "|")
  grantAgency <- sapply(strsplit(grantAgency, "|", fixed = TRUE), unique)
  grantAgency <- sapply(grantAgency, paste, collapse = "|")
  names(grantAgency) <- NULL
  grantNumber <- lapply(records, xpathSApply, ".//Grant/GrantID", xmlValue)
  grantNumber[sapply(grantNumber, is.list)] <- NA
  grantNumber <- sapply(grantNumber, paste, collapse = "|")
  grantCountry <- lapply(records, xpathSApply, ".//Grant/Country", xmlValue)
  grantCountry[sapply(grantCountry, is.list)] <- NA
  grantCountry <- sapply(grantCountry, paste, collapse = "|")
  grantCountry <- sapply(strsplit(grantCountry, "|", fixed = TRUE), unique)
  grantCountry <- sapply(grantCountry, paste, collapse = "|")
  nctID <- lapply(records, xpathSApply, ".//DataBank[DataBankName = 'ClinicalTrials.gov']/AccessionNumberList/AccessionNumber", xmlValue)
  nctID[sapply(nctID, is.null)] <- NA
  nctID <- sapply(nctID, paste, collapse = "|")
  ptype <- lapply(records, xpathSApply, ".//PublicationType", xmlValue)
  ptype[sapply(ptype, is.list)] <- NA
  ptype <- sapply(ptype, paste, collapse = "|")
  theDF <- data.frame(pmid, doi, authors, year, articletitle, journal, volume, issue, pages, abstract, meshHeadings, chemNames, grantAgency, grantNumber, grantCountry, nctID, ptype, stringsAsFactors = FALSE)
  return(theDF)
}

##########################################
##            TF,IDF,TF-IDF             ##
##########################################
#TF#
tf = function(row)
{
  row/sum(row)
}
#IDF
inverse_df = function(col)
{
  size = length(col)
  doc_count = length(which(col>0))
  log10(size/doc_count)
}
#TF-IDF
tf_idf = function(tf,idf)
{
  tf*idf 
}

##########################################
##########################################
##########################################

search_abstract = function()
{
  data = data.frame()
  keyword = readline("Sorguyu gir : ") 
  #####kütüphaneler####
  #install.packages("rentrez")
  #install.packages("writexl")
  #install.packages("quanteda")
  library(quanteda)
  library(rentrez)
  library(writexl)
  library(dplyr)
  ##############
  #mystopwords = read.delim(file.choose())
  print(" Sorgu Aranıyor...")
  df_ids <- entrez_search(db = "pubmed", term = keyword, use_history = TRUE)  # Pubmed apisinden sorguyu aratma.
  cat(df_ids$count," adet sonuç bulundu.")
  #use_history geçmiş sunucuya indirip daha sonra indirmeye yarayacak..
  ###########
  if(df_ids$count>10000)
  {
    for(i in seq(1,df_ids$count,10000))
    {
      df <- entrez_fetch(db = "pubmed", web_history = df_ids$web_history,rettype = "xml",retstart = i )
      df1 = xml_to_frame(df)
      data = rbind(data,df1)
    }
  } else {df = entrez_fetch(db = "pubmed", web_history = df_ids$web_history,rettype = "xml")
  data = xml_to_frame(df)}
  data = dplyr::select(data,c("pmid","articletitle","abstract","chemNames","meshHeadings"))
  #####
  #ön işleme
  na_index = which(data$abstract %in% "NA")
  data = data[-na_index,]
  data$text_length = nchar(data$abstract)# makalelerin kelime sayısı
  kaydet = readline("Bulunan makaleleri bilgisayarınıza kaydetmek istiyor musunuz ? (E-H) : ")
  if(kaydet == "E")
  {
    write_xlsx(x = data,path = "veri.xlsx",col_names = TRUE) # dataframeyi dışa aktarma
  }
  View(data )
  
  #VERİ ÖN İŞLEME ADIMLARI
  #Tüm harfleri kücült
  #Noktalama işaretlerini kaldır
  #Sayıları kaldır
  #stopwords\'leri kaldır
  #Sembolleri kaldır
  #Kelimeleri köklerine ayır
  
  #Tokenleştirme
  tokenabstract = tokens(data$abstract,what = "word",remove_punct = T,
                         remove_symbols = T,remove_numbers = T,remove_url = T,
                         remove_separators = T,split_hyphens = T)
  
  # Lovercase
  lovertokens = tokens_tolower(tokenabstract)
  
  #Stopwords
  stopwords_tokens = tokens_select(lovertokens,stopwords("en"),
                                   selection = "remove")     #tokens_select fonksiyonu tokenlerin
  #                                                           içinden belirtilen nesneleri seçerek çıkarır veya tutar.                                            
  # stopwordlerin içinde şapkalı a olmnadığı için özel olarak çıkarma işlemi yapıyoruz.
  stopwords_tokens = tokens_select(stopwords_tokens,"â",selection = "remove")
  View(stopwords_tokens)
  #Stemming(köklere ayırma)
  stem_tokens = tokens_wordstem(stopwords_tokens,language = "porter")
  
  #########################################################################
  #                                DFM                                    #
  # Token işlemi yapılan veride her kelimenin ne kadar geçtiğini gösterir.#
  #########################################################################
  dfm_tokens = dfm(stopwords_tokens,tolower = F)
  dfm_matrix = as.matrix(dfm_tokens)
  View(dfm_matrix)
  #########################################################################
  
  #########################################################################
  #                           Normalleştirme                              #
  #   Oluştulan TF fonksiyonu ile terim frekansları standartlaştırılır.   #
  #########################################################################
  normdoc = apply(dfm_matrix,1,tf)
  View(normdoc)
  ###########################
  # IDF ve TF-IDF işlemleri #
  ###########################
  #idf
  normdoc_idf = apply(normdoc,2,inverse_df)
  #tf-idf
  normdoc_tfidf = apply(normdoc,2,tf_idf,idf = normdoc_idf)
  #transpose matrix
  transpose_tfidf = t(normdoc_tfidf)
  View(transpose_tfidf)
}



####################################
#              N-Gram              #
####################################
stopwords_tokens = tokens_ngrams(stopwords_tokens,n = 1:2)
stopwords_tokens[[7]]

dfm_tokens = dfm(stopwords_tokens,tolower = F)
dfm_matrix = as.matrix(dfm_tokens)

#normalleştirme
normdoc_ngram = apply(dfm_matrix,1,tf)
#idf
normdoc_idf_ngram = apply(normdoc_ngram,2,inverse_df)
#tf-idf
normdoc_tfidf_ngram = apply(normdoc_ngram,2,tf_idf,idf = normdoc_idf_ngram)
#transpose matrix
transpose_tfidf_ngram = t(normdoc_tfidf_ngram)

###LSD
install.packages("irlba")
library(irlba)
start_time = Sys.time()
##
train_irlba = irlba(transpose_tfidf,nv = 100,maxit = 600)

###LSA
install.packages("lsa")
library(lsa)
View(cosine(normdoc_tfidf_ngram))







