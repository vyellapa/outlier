##### outlier.R #####
# Kuan-lin Huang @ WashU 2015 Oct
# outlier analysis pipeline
# called by other scripts

### dependencies ###
### common libs and dependencies ### 
# especially for plotting #

# dependencies
library(ggplot2)
library(reshape2)
library(RColorBrewer)
library(matrixStats)

##### READ DATA #####
get_val_arg = function( args , flag , default ) {
    ix = pmatch( flag , args ); #partial match of flag in args, returns index in argument list
    if ( !is.na( ix ) ) { #ix is a pmatch of flag in args
        if ( is.numeric( default ) ) {
            val = as.numeric( args[ix+1] );
        } else {
            val = args[ix+1];
        }
    } else {
        val = default;
    }
    return( val );
}

get_bool_arg = function( args , flag ) {
    ix = pmatch( flag , args );
    if ( !is.na( ix ) ) {
        val = TRUE;
    } else {
        val = FALSE;
    }
    return( val );
}

get_list_arg = function( args , flag , nargs , default ) {
    ix = pmatch( flag , args ); #partial match of flag in args
    vals = 1:nargs;
    if ( !is.na( ix ) ) { #ix is a pmatch of flag in args
        for ( i in 1:nargs ) {
            if ( is.numeric( default ) ) {
                vals[i] = as.numeric( args[ix+i] );
            } else {
                vals[i] = args[ix+i];
            }
        }
    } else {
        for ( i in 1:nargs ) {
            vals[i] = default;
        }
    }
    return( vals );
}


parse_args = function() {
    args = commandArgs( trailingOnly = TRUE ); #tailingOnly = TRUE, arguments after --args are returned

    geneListFile = get_val_arg( args , "-l" , "" );
#    geneCongersionFile = get_val_arg( args , "-c" , "" );
    matrixFile = get_val_arg( args , "-m" , "" );
    outputDir = get_val_arg( args , "-o" , "" );

    val = list( 'geneListFile' = geneListFile ,
#				'geneConversionFile' = geneConversionFile , 
				'outputDir' = outputDir , 
                'matrixFile' = matrixFile );

    return( val );
}
#get args
args = parse_args();
geneListFile = args$geneListFile
#geneConversionFile = args$geneConversionFile
outputDir = args$outputDir
odir = strsplit( outputDir , "/" )
matrixFile = args$matrixFile

# read in a gene list
geneList = read.table(header=FALSE, stringsAsFactors = F, file = geneListFile )
geneVector = as.vector(t(geneList))
# expect a gene-sample (row-column) dataset
expTab = read.table(header=TRUE, sep="\t", file= matrixFile )
cat( paste( c( "There are" , nrow( expTab ) , "genes and" , ncol( expTab ) , "samples in the expression matrix\n" ) ) )
names = make.names(expTab[,1], unique =T)
row.names(expTab) = names

##### ALGORITHM #####

# mis
#system("mkdir figures")
date=Sys.time()
date = sub(" .*","",date)
pd = paste( outputDir , date , sep = "/" )

##### functions #####
unfactorize = function(df){
  for(i in which(sapply(df, class) == "factor")) df[[i]] = as.numeric(as.character(df[[i]]))
  return(df)
}

##### use the box plot definition of outlier, then rank them by the outlier score ##### 
find_outlier = function(m, name="dataset", barplot = TRUE, plot=TRUE, printOrderTables=F, h=30, w=44, minNum = 10){ 
  #w=40 for human panels with ~80 samples
  cat("##### OUTLIER ANALYSIS #####\n")
  m = as.matrix(m)
  num = nrow(m)
  m2 = as.matrix(m[rowSums(!is.na(m)) >= minNum, ])
  num_NA= nrow(m2)
  cat(paste("Looking for outliers in", deparse(substitute(genes)), "of", name, "\n", sep=" "))
  cat(paste("Original number of markers:", num, "; NA filtered:", num_NA, "\n", sep=" "))
  
	if ( nrow(m2) <= 0 ) {
		cat( "No outliers\n" )
		return(list("outlier_score"= NULL , "outlier"= NULL , "count_results"= NULL ,
					"top_outlier_zscore"= NULL , "top_outlier"= NULL , "top_outlier_boolean"= NULL ))
	}
  ##### outlier analysis #####
  outlier = matrix(,nrow=dim(m2)[1],ncol=dim(m2)[2])
  row.names(outlier) = row.names(m2)
  colnames(outlier) = colnames(m2)
  outlier_mzscore = outlier
  outlier_box = outlier
  #outlier_box2 = outlier # more stringent outlier definition based on outer fences
  
  # gene-wise outlier and outlier score
  for (i in 1:nrow(m2)){
    # modified z-score for outlier: Boris Iglewicz and David Hoaglin (1993), "Volume 16: How to Detect and Handle Outliers", The ASQC Basic References in Quality Control: Statistical Techniques, Edward F. Mykytka, Ph.D., Editor.
    # outlier_mzscore[i,]  = 0.6745*(m2[i,]-median(m2[i,], na.rm=TRUE))/mad(m2[i,], na.rm=TRUE)
    
    # box-plot definition of outlier
    IQR = quantile(m2[i,], probs=0.75, na.rm=T) - quantile(m2[i,], probs=0.25, na.rm=T) 
    outlier_box[i,] = (m2[i,] >= quantile(m2[i,], probs=0.75, na.rm=T) + 1.5*IQR)
    # outlier_box2[i,] = (m2[i,] >= quantile(m2[i,], probs=0.75, na.rm=T) + 3.5*IQR) #outer fences
    outlier_mzscore[i,] = (m2[i,] - quantile(m2[i,], probs=0.75, na.rm=T))/IQR
  }
  
  # output the outlier score table
  fn = paste(pd,name,'outlier_score_table.txt', sep="_")
  write.table(outlier_mzscore, file=fn, quote=F, row.names=T, sep="\t", col.names=NA)
  
  num_outliers = sum(outlier_box, na.rm=T)
  cat(paste("Number_of_samples:", dim(outlier)[2], "Number_of_outliers:", num_outliers,"; Avg_outlier_per_sample:", num_outliers/dim(outlier)[2], "\n\n", sep = " "))
  
  results = data.frame(rowSums(outlier_mzscore >= 1))
  colnames(results)[1]= "count"
  results = results[order(results[,1], decreasing=T),,drop=F]
  results$cohort = name
  results$cohort_size = dim(outlier)[2]
  results$freq = results$count/results$cohort_size
  results$marker = row.names(results)
  results = results[,c(5,2,3,1,4)]
  
  fn = paste(pd,name,'outlier_gene_counts.txt', sep="_")
  write.table(results, file=fn, quote=F, row.names=F, sep="\t", col.names=T)
  
  # plotting bar plots indicating number of samples having the gene outlier
  if (barplot){
    fn = paste(pd, name, '_outlier_gene_counts.pdf',sep ="_")
    results_sum = results#[c(1:10),,drop=F]
    results_sum$marker = factor(results_sum$marker, levels = results_sum$marker[order(results_sum$count, decreasing=T)])
    
    p = ggplot(data=results_sum, aes(x=marker, y=count))
    p = p + geom_bar(stat="identity")
    p = p + labs(title = name, x="Markers", y="Count of samples") + theme_bw() #+ ylim(c(0,100))
    p = p + theme(text = element_text(colour="black", size=18), axis.text.x = element_text(angle = 90, vjust = 0.5, colour="black", size=14), axis.text.y = element_text(colour="black", size=14))
    p
    ggsave(file=fn, useDingbats=FALSE)   
  }
  
  ##### rank outliers and set up return matrixes #####
  zscore=outlier_mzscore
  outlier=outlier_box
  num_genes = dim(zscore)[1] 
  top_outlier_zscore = matrix(,nrow=dim(zscore)[2],ncol=num_genes)
  top_outlier = matrix(,nrow=dim(zscore)[2],ncol=num_genes)
  top_outlier_boolean = matrix(,nrow=dim(zscore)[2],ncol=num_genes)
  top_outlier_raw = matrix(,nrow=dim(zscore)[2],ncol=num_genes)
  row.names(top_outlier_zscore)=colnames(zscore)
  row.names(top_outlier)=colnames(zscore)
  row.names(top_outlier_boolean)=colnames(zscore)
  row.names(top_outlier_raw)=colnames(zscore)
  colnames(top_outlier_zscore)=c(1:num_genes)
  for (i in 1:num_genes){colnames(top_outlier_zscore)[i] = paste(name, colnames(top_outlier_zscore)[i], sep=" ")}
  colnames(top_outlier)=colnames(top_outlier_zscore)
  colnames(top_outlier_boolean)=colnames(top_outlier_zscore)
  colnames(top_outlier_raw)= colnames(top_outlier_zscore)
  
  # rank order based on zscore
  for (i in colnames(zscore)){
    whim=zscore[,i]
    a = whim[order(whim, decreasing=TRUE)][1:num_genes]
    top_outlier_zscore[i,] = a
    whim2 = outlier[,i]
    top_outlier_boolean[i,] = whim2[order(whim, decreasing=TRUE)][1:num_genes]
    whim3 = m2[,i]
    top_outlier_raw[i,] = whim3[order(whim, decreasing=TRUE)][1:num_genes]
    top_outlier[i,] = names(a)
  }
  
  # whether the ordered outlier tables will be saved as additional txt files
  if (printOrderTables){
    a=rbind(top_outlier, top_outlier_zscore)
    a = a[order(row.names(a)),]
    fn = paste(pd,name,'outlier_score.txt', sep="_")
    write.table(a, file=fn, quote=F, row.names=T, sep="\t", col.names=NA)
    
    b=rbind(top_outlier, top_outlier_raw)
    b = b[order(row.names(b)),]
    fn = paste(pd,name,'outlier_raw_exp.txt', sep="_")
    write.table(b, file=fn, quote=F, row.names=T, sep="\t", col.names=NA)
    
    c=rbind(top_outlier, top_outlier_boolean)
    c = c[order(row.names(c)),]
    fn = paste(pd,name,'outlier.txt', sep="_")
    write.table(c, file=fn, quote=F, row.names=T, sep="\t", col.names=NA)
  }
  
  ##### plotting #####
  # determine how many outliers should be shown
  num_shown=1
  for (i in 1:nrow(top_outlier_boolean)){
    row_outlier = sum(top_outlier_boolean[i,], na.rm=T)
    if (row_outlier > num_shown) {num_shown = row_outlier}
  }
  
  # version that plotted everything
  if (plot){
    if (num_shown > 5) {num_shown=5} # hard threshold on numbers of outliers shown
    top_outlier.m <- melt(top_outlier[,c(1:num_shown)])
    top_outlier_zscore.m <- melt(top_outlier_zscore[,c(1:num_shown)])
    top_outlier_boolean.m <- melt(top_outlier_boolean[,c(1:num_shown)])
    colnames(top_outlier.m)=c("Var1","Var2","value")
    colnames(top_outlier_zscore.m)=c("Var1","Var2","value")
    colnames(top_outlier_boolean.m)=c("Var1","Var2","value")
    
    fn = paste(pd, name, 'top_outlier_score_all.pdf',sep ="_")
    YlOrRd = brewer.pal(9, "YlOrRd") 
    getPalette = colorRampPalette(YlOrRd)
    outlier.colors=c("NA", "#000000")
    
    p = ggplot()
    p = p + geom_tile(data=top_outlier_zscore.m, aes(x=as.factor(Var1), y=Var2, fill=value), linetype="blank") + scale_fill_gradientn(name= "Outlier score", colours=getPalette(100))
    p = p + geom_tile(data=top_outlier_boolean.m, aes(x=as.factor(Var1), y=Var2, color=value), fill=NA, size=0.5) + scale_colour_manual(name="Outlier",values = outlier.colors)
    p = p + geom_text(data=top_outlier.m,aes(x=as.factor(Var1), y=Var2, label = value), color="black", size=4, angle=90)
    p = p + xlab("Sample") + ylab("Top Druggable Outliers") + theme_bw() + 
      theme(axis.title = element_text(size=18), axis.text.x = element_text(angle = 90, vjust = 0.5, colour="black", size=16), axis.text.y = element_blank(),axis.ticks.y = element_blank())#element_text(colour="black", size=16))
    p
    ggsave(file=fn, height=h, width=w, useDingbats=FALSE)
  }
  
  
  # return the top outliers
  return(list("outlier_score"=outlier_mzscore, "outlier"=outlier, "count_results"=results,
              "top_outlier_zscore"=top_outlier_zscore, "top_outlier"=top_outlier, "top_outlier_boolean"=top_outlier_boolean))
}

##### MAIN #####

expTab.d = expTab[names %in% geneVector,-1] # extract only the geneVector genes; get rid of row names
expTab.d = log2(unfactorize(expTab.d)+1) # log2 transofrm
expTab_geneVector = find_outlier(expTab.d, name = paste( strsplit( geneListFile , "/" )[[1]][-1] , strsplit( matrixFile , "/" )[[1]][-1] , "geneVector_exp" , sep = "." ) ) # find outlier

