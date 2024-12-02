import os
import sys
from dotenv import load_dotenv
from langchain_community.document_loaders import PyPDFLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains.summarize import load_summarize_chain
from langchain_openai import ChatOpenAI

def check_api_key():
    """Check if the OpenAI API key is properly set"""
    if not os.getenv('OPENAI_API_KEY'):
        raise ValueError(
            "OpenAI API key not found! Please add your API key to the .env file:\n"
            "OPENAI_API_KEY=your_api_key_here"
        )

def summarize_pdf(pdf_path):
    """
    Summarize a PDF document using LangChain and OpenAI.
    
    Args:
        pdf_path (str): Path to the PDF file
        
    Returns:
        str: Summary of the PDF document
    """
    try:
        # Load environment variables
        load_dotenv()
        check_api_key()
        
        # Initialize the PDF loader
        loader = PyPDFLoader(pdf_path)
        documents = loader.load()
        
        # Split the document into chunks
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=2000,
            chunk_overlap=200,
            length_function=len
        )
        splits = text_splitter.split_documents(documents)
        
        # Initialize the language model
        llm = ChatOpenAI(
            temperature=0,
            model_name="gpt-3.5-turbo-16k"
        )
        
        # Create and run the summarization chain
        chain = load_summarize_chain(
            llm=llm,
            chain_type="map_reduce",
            verbose=True
        )
        
        # Generate the summary
        summary = chain.invoke(splits)["output_text"]
        return summary
        
    except ValueError as ve:
        raise ve
    except Exception as e:
        raise Exception(f"Error processing PDF: {str(e)}")

def main():
    print("PDF Research Document Summarizer")
    print("-" * 30)
    
    # Get PDF path from command line argument or use default
    if len(sys.argv) > 1:
        pdf_file = sys.argv[1]
    else:
        pdf_file = "sample_research.pdf"
    
    # Validate file existence
    if not os.path.exists(pdf_file):
        print(f"Error: The specified PDF file '{pdf_file}' does not exist.")
        return
    
    # Validate file extension
    if not pdf_file.lower().endswith('.pdf'):
        print("Error: The file must be a PDF document.")
        return
    
    try:
        print(f"\nProcessing PDF: {pdf_file}")
        print("This may take a few minutes depending on the document size...")
        summary = summarize_pdf(pdf_file)
        
        print("\nSummary of the PDF document:")
        print("-" * 50)
        print(summary)
        
    except ValueError as ve:
        print(f"\nConfiguration Error: {str(ve)}")
    except Exception as e:
        print(f"\nAn error occurred: {str(e)}")

if __name__ == "__main__":
    main()
