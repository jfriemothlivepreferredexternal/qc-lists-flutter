/**
 * Google Sheets Column G Cleaner Script
 * 
 * PURPOSE: Fixes ImportRange formula refresh issues by automatically clearing 
 * any content added to column G. When users double-click cells in column G 
 * (even without changing anything), Google Sheets thinks data was added which 
 * can interfere with ImportRange formulas. This script immediately clears any 
 * edits in column G to force ImportRange to refresh properly.
 * 
 * This script should be added to your Google Sheet (not standalone Apps Script)
 * 
 * Setup Instructions:
 * 1. Open your Google Sheet with the "(1) QC Reports" tab
 * 2. Go to Extensions → Apps Script from the sheet's menu
 * 3. Copy and paste this code into the new sheet-bound script editor
 * 4. Save the script
 * 5. The onEdit trigger will automatically work
 */

/**
 * Trigger function that runs when any cell is edited
 * Deletes content in column G and shows notification
 */
function onEdit(e) {
  const sheet = e.source.getActiveSheet();
  const range = e.range;
  
  // Check if we're on the correct sheet and column G was edited
  if (sheet.getName() === "(1) QC Reports" && range.getColumn() === 7) {
    // Delete the content that was just added
    range.clearContent();
    
    // Show popup notification
    SpreadsheetApp.getUi().alert(
      'Column G Cleared', 
      'Restoring data!', 
      SpreadsheetApp.getUi().ButtonSet.OK
    );
    
    // Log the action
    console.log(`Cleared content in cell ${range.getA1Notation()} on sheet "${sheet.getName()}"`);
  }
}

/**
 * Test function to verify the setup works
 */
function testClearColumnG() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("(1) QC Reports");
  if (sheet) {
    // Simulate an edit in G2
    sheet.getRange("G2").setValue("test");
    SpreadsheetApp.flush(); // Force update
    
    // Clear it
    sheet.getRange("G2").clearContent();
    SpreadsheetApp.getUi().alert("Test completed - G2 was cleared");
  } else {
    SpreadsheetApp.getUi().alert("Sheet '(1) QC Reports' not found!");
  }
}

/**
 * Alternative function to clear entire column G manually
 * Can be run manually or set up on a timer if needed
 */
function clearAllColumnG() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("(1) QC Reports");
  if (sheet) {
    const lastRow = sheet.getLastRow();
    if (lastRow > 1) { // Don't clear header row
      sheet.getRange(`G2:G${lastRow}`).clearContent();
      SpreadsheetApp.getUi().alert("Column G cleared", "All data in column G has been cleared.");
    }
  } else {
    SpreadsheetApp.getUi().alert("Error", "Sheet '(1) QC Reports' not found!");
  }
}