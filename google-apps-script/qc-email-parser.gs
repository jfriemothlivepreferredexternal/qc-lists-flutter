/**
 * QC Lists Email Parser for Google Apps Script
 * 
 * This script automatically processes emails from the QC Lists Flutter app
 * and creates rows in a Google Sheet with the parsed email data. The contents in the email body are included also, but not parsed.
 * 
 * Setup Instructions:
 * 1. Create a new Google Apps Script project at script.google.com
 * 2. Copy and paste this code into the script editor
 * 3. Update the SPREADSHEET_ID constant below with your Google Sheet ID
 * 4. Set up a trigger to run processQCEmails() periodically
 * 5. Grant necessary permissions when prompted
 */

// Configuration - UPDATE THESE VALUES
const SPREADSHEET_ID = '1OnodEciukIX-grhcXIZG6sM5haRt0QnQJWBVv2ThuGg'; // Replace with your actual Google Sheet ID?
const SHEET_NAME = 'QC Reports'; // Name of the sheet tab
const SEARCH_QUERY = 'subject:"QC" subject:"Complete" is:unread'; // Gmail search query for QC emails

/**
 * Main function to process QC emails
 * Set up a repeatable trigger to run this function periodically
 */
function processQCEmails() {
  try {
    console.log('Starting QC email processing...');
    
    // Search for unread QC emails
    const threads = GmailApp.search(SEARCH_QUERY, 0, 50);
    console.log(`Found ${threads.length} unread QC email threads`);
    
    if (threads.length === 0) {
      console.log('No new QC emails to process');
      return;
    }
    
    // Get or create the spreadsheet
    const sheet = getOrCreateSheet();
    
    // Process each thread
    threads.forEach(thread => {
      const messages = thread.getMessages();
      messages.forEach(message => {
        if (message.isUnread()) {
          processQCEmail(message, sheet);
          message.markRead(); // Mark as read after processing
        }
      });
    });
    
    console.log('QC email processing completed');
    
  } catch (error) {
    console.error('Error processing QC emails:', error);
    // Optionally send error notification email
    sendErrorNotification(error);
  }
}

/**
 * Parse QC email subject line to extract template, percentage, building, and unit
 * Expected format: "QC [Template Name] - [XX]% Complete - B[#]U[#]"
 */
function parseSubject(subject) {
  const parsed = {
    templateName: '',
    completionPercent: '',
    building: '',
    unit: '',
    propertyName: ''
  };
  
  try {
    // Extract template name (between "QC " and " - ")
    const templateMatch = subject.match(/QC\s+(.+?)\s+-\s+\d+%/);
    if (templateMatch) {
      let templateName = templateMatch[1].trim();
      // Normalize QC6.ALT to just QC6
      if (templateName.includes('.ALT')) {
        templateName = templateName.replace('.ALT', '');
      }
      parsed.templateName = templateName;
    }
    
    // Extract completion percentage
    const percentMatch = subject.match(/(\d+)%\s+Complete/);
    if (percentMatch) {
      parsed.completionPercent = percentMatch[1] + '%';
    }
    
    // Extract building and unit (B[#]U[#])
    const buildingUnitMatch = subject.match(/B(\d+)U(\d+)/);
    if (buildingUnitMatch) {
      parsed.building = buildingUnitMatch[1];
      parsed.unit = buildingUnitMatch[2];
    }
    
    // Extract property name (after B[#]U[#] - )
    const propertyMatch = subject.match(/B\d+U\d+\s+-\s+(.+)$/);
    if (propertyMatch) {
      parsed.propertyName = propertyMatch[1].trim();
    }
    
  } catch (error) {
    console.error('Error parsing subject:', error);
  }
  
  return parsed;
}

/**
 * Process a single QC email and extract data
 */
function processQCEmail(message, sheet) {
  try {
    const subject = message.getSubject();
    const body = message.getPlainBody();
    const receivedTime = message.getDate();
    const sender = message.getFrom();
    
    console.log(`Processing email: ${subject}`);
    
    // Parse subject line for QC data
    const subjectData = parseSubject(subject);
    
    // Create simple data object
    const data = {
      emailSubject: subject,
      emailSender: sender,
      emailReceived: receivedTime,
      processedTime: new Date(),
      emailBody: body,
      templateName: subjectData.templateName,
      completionPercent: subjectData.completionPercent,
      building: subjectData.building,
      unit: subjectData.unit,
      propertyName: subjectData.propertyName
    };
    
    // Add row to sheet
    addDataToSheet(sheet, data, message.getAttachments());
    
    console.log(`Successfully processed email from ${sender}`);
    
  } catch (error) {
    console.error(`Error processing individual email: ${error}`);
  }
}

/**
 * Add parsed data to the Google Sheet
 */
function addDataToSheet(sheet, data, attachments) {
  try {
    // Prepare the row
    const row = [
      data.propertyName,
      data.emailSubject,
      data.templateName,
      data.completionPercent,
      data.building,
      data.unit,
      data.emailBody,
      data.emailSender,
      data.emailReceived,
      data.processedTime
    ];

    // Add attachment URLs as separate columns
    attachments.forEach((attachment, index) => {
      const file = DriveApp.createFile(attachment);
      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
      const publicUrl = file.getUrl();

      // Log the URL for debugging
      console.log(`Attachment ${index + 1} URL: ${publicUrl}`);

      row.push(publicUrl); // Add the URL as plain text
    });

    // Add row to sheet
    sheet.appendRow(row);

    console.log('Added 1 row to sheet');

  } catch (error) {
    console.error('Error adding data to sheet:', error);
  }
}

/**
 * Get or create the target Google Sheet
 */
function getOrCreateSheet() {
  try {
    const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
    let sheet = spreadsheet.getSheetByName(SHEET_NAME);
    
    if (!sheet) {
      // Create new sheet if it doesn't exist
      sheet = spreadsheet.insertSheet(SHEET_NAME);
      
      // Add headers
      const headers = [
        'Property Name',
        'Subject',
        'Template Name',
        'Completion %',
        'Building',
        'Unit',
        'Email Body',
        'Sent By',
        'Email Received',
        'Processed Time'
      ];
      
      sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
      
      // Format header row
      const headerRange = sheet.getRange(1, 1, 1, headers.length);
      headerRange.setBackground('#4285f4');
      headerRange.setFontColor('white');
      headerRange.setFontWeight('bold');
      
      console.log(`Created new sheet: ${SHEET_NAME}`);
    }
    
    return sheet;
    
  } catch (error) {
    console.error('Error getting/creating sheet:', error);
    throw error;
  }
}

/**
 * Send error notification email
 */
function sendErrorNotification(error) {
  try {
    const subject = 'QC Email Parser Error';
    const body = `An error occurred while processing QC emails:\n\n${error.toString()}\n\nTime: ${new Date()}\n\nPlease check the Google Apps Script logs for more details.`;
    
    // Send to the script owner (you can modify this to send to specific email)
    GmailApp.sendEmail(Session.getActiveUser().getEmail(), subject, body);
    
  } catch (emailError) {
    console.error('Error sending error notification:', emailError);
  }
}


function testEmailParsing() {
  const sampleSubject = 'QC Electrical Systems - 85% Complete - B5U12';
  const sampleEmailBody = `Sample QC checklist email body - not parsed by this script.`;
  
  const parsedSubject = parseSubject(sampleSubject);
  console.log('Sample subject:', sampleSubject);
  console.log('Parsed subject data:', JSON.stringify(parsedSubject, null, 2));
  console.log('Email body length:', sampleEmailBody.length);
}

/**
 * Setup function, run once to set up triggers
 */
function setupTriggers() {
  // Delete existing triggers for this function
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(trigger => {
    if (trigger.getHandlerFunction() === 'processQCEmails') {
      ScriptApp.deleteTrigger(trigger);
    }
  });
  
  // Create new trigger to run every 5 minutes
  ScriptApp.newTrigger('processQCEmails')
    .timeBased()
    .everyMinutes(5)
    .create();
    
  console.log('Trigger set up to run processQCEmails every 5 minutes');
}