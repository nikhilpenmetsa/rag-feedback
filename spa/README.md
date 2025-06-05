# AI Chat Interface SPA

A simple single-page application (SPA) for interacting with the AI conversation API.

## Features

- Clean, modern chat interface
- Real-time conversation with AI assistant
- Ready for feedback integration (thumbs up/down)
- Deployable to AWS CloudFront

## Local Development

### Prerequisites

- Node.js and npm
- AWS CLI configured with appropriate permissions

### Running Locally

1. Navigate to the project directory:
   ```
   cd spa
   ```

2. Install dependencies:
   ```
   npm install
   ```

3. Start the local development server:
   ```
   npm start
   ```

4. Open your browser and navigate to `http://localhost:3000`

## Deployment to CloudFront

1. Navigate to the scripts directory:
   ```
   cd spa/scripts
   ```

2. Run the deployment script:
   ```
   .\deploy.ps1
   ```

   You can customize the deployment with parameters:
   ```
   .\deploy.ps1 -BucketName "my-spa-bucket" -StackName "my-spa-stack" -Region "us-west-2"
   ```

3. After deployment completes, you'll receive a CloudFront URL where your application is hosted.

## Configuration

To change the API endpoint, edit the `API_ENDPOINT` variable in `public/app.js`.

## Future Enhancements

- Integration with feedback API (thumbs up/down)
- User authentication
- Conversation history
- Markdown rendering for responses