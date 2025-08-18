const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");
// ========== SECRETS MANAGER CLIENT ==========
const secretsClient = new SecretsManagerClient({ region: "ap-southeast-1" });
let cachedSecrets = null;

const getSecrets = async () => {
  if (cachedSecrets) return cachedSecrets;

  const command = new GetSecretValueCommand({ SecretId: "prod/openai/api-key" });
  const secret = await secretsClient.send(command);
  cachedSecrets = JSON.parse(secret.SecretString || "{}");
  return cachedSecrets;
};

// ========== CORS HEADERS ==========
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,User-Agent",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Content-Type": "application/json"
};

// AI Configuration
const AI_MODEL = "gpt-4";
const AI_MAX_TOKENS = 50;
const AI_TEMPERATURE = 0.5;
const AI_TOP_P = 0.85;
const AI_FREQUENCY_PENALTY = 0.1;
const AI_PRESENCE_PENALTY = 0.2;

// ========== ERROR RESPONSE HELPER ==========
const createErrorResponse = (statusCode, errorType, error, message = null, details = null) => {
  const errorResponse = {
    error,
    error_type: errorType,
    timestamp: new Date().toISOString()
  };
  
  if (message) errorResponse.message = message;
  if (details) errorResponse.details = details;
  
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify(errorResponse)
  };
};

// ========== HTTP REQUEST FUNCTION ==========
const makeHttpRequest = async (url, options = {}) => {
  const https = require('https');
  const { URL } = require('url');
  
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const isHttps = parsedUrl.protocol === 'https:';
    const client = isHttps ? https : http;
    
    const requestOptions = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || (isHttps ? 443 : 80),
      path: parsedUrl.pathname + parsedUrl.search,
      method: options.method || 'GET',
      headers: options.headers || {}
    };
    
    const req = client.request(requestOptions, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        const response = {
          ok: res.statusCode >= 200 && res.statusCode < 300,
          status: res.statusCode,
          statusText: res.statusMessage,
          json: async () => JSON.parse(data),
          text: async () => data
        };
        resolve(response);
      });
    });
    
    req.on('error', (err) => {
      reject(err);
    });
    
    // Set timeout for the request
    req.setTimeout(30000, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    
    if (options.body) {
      req.write(options.body);
    }
    
    req.end();
  });
};

// ========== MAIN HANDLER ==========
const handler = async (event) => {
  console.log("Event received:", JSON.stringify(event, null, 2));
  
  try {
    // Handle preflight OPTIONS requests
    if (event.httpMethod === 'OPTIONS') {
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: ""
      };
    }

    const path = (event.path || event.rawPath || event.resource || "").toLowerCase();
    const httpMethod = event.httpMethod || event.requestContext?.http?.method || "";
    
    console.log(`Processing ${httpMethod} request to path: ${path}`);

    // Route to appropriate handler
    if (path.includes("/plan")) {
      return await generateFitnessPlan(event);
    }
    if (path.includes("/quote")) {
      return await fetchMotivationalQuote();
    }
    if (path.includes("/image")) {
      return await fetchMotivationImage();
    }

    return createErrorResponse(
      404, 
      "not_found", 
      "Endpoint not found", 
      `Path '${path}' is not available`,
      { 
        path: path,
        availableEndpoints: ["/plan", "/quote", "/image"]
      }
    );
  } catch (err) {
    console.error("Handler error:", err);
    return createErrorResponse(
      500,
      "unhandled_exception",
      "Internal Server Error",
      err.message
    );
  }
};

// ========== FITNESS PLAN GENERATOR ==========
const generateFitnessPlan = async (event) => {
  console.log("Generating fitness plan...");
  
  try {
    let body = {};
    
    // Parse request body
    if (event.httpMethod === "GET" && event.queryStringParameters) {
      body = event.queryStringParameters;
    } else if (event.body) {
      try {
        body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
        if (body.user_data) {
          console.log("Extracting user_data from request");
          body = body.user_data;
        }
      } catch (parseError) {
        console.error("JSON parse error:", parseError);
        return createErrorResponse(
          400,
          "validation",
          "Invalid JSON in request body",
          "The request body contains invalid JSON format"
        );
      }
    }

    console.log("Request body:", JSON.stringify(body, null, 2));

     const data = {
      age: parseInt(body.age),
      sex: body.sex,
      weight: parseFloat(body.weight),
      height: parseFloat(body.height),
      fitnessLevel: body.fitnessLevel,
      goal: body.goal,
      bodyFocus: body.bodyFocus,
      intensity: parseInt(body.intensity),
      minWorkouts: parseInt(body.minWorkouts),
      maxWorkouts: parseInt(body.maxWorkouts),
      minRepsPerWorkout: parseInt(body.minRepsPerWorkout),
      maxRepsPerWorkout: parseInt(body.maxRepsPerWorkout),
      minIntensity: parseInt(body.minIntensity),
      maxIntensity: parseInt(body.maxIntensity)
    };
    
    const allowedWorkouts = (body.allowedWorkouts || []).join(", ");
    const todayDate = new Date().toISOString().split('T')[0];

    console.log("Configuration constants received:");
    console.log("Allowed workouts: ", allowedWorkouts);
    console.log(`Min reps per workout: ${data.minRepsPerWorkout}`);
    console.log(`Max reps per workout: ${data.maxRepsPerWorkout}`);
    console.log(`Min intensity: ${data.minIntensity}`);
    console.log(`Max intensity: ${data.maxIntensity}`);

    // Get OpenAI API key
    let secrets;
    try {
      secrets = await getSecrets();
    } catch (secretError) {
      console.error("Error retrieving secrets:", secretError);
      return createErrorResponse(
        500,
        "configuration_error",
        "Configuration error",
        "Unable to retrieve API configuration"
      );
    }

    const { OPENAI_API_KEY } = secrets;
    if (!OPENAI_API_KEY) {
      return createErrorResponse(
        500,
        "configuration_error",
        "OpenAI API key not found",
        "API configuration is incomplete"
      );
    }
    // System prompt
    const systemPrompt =
`You are a professional fitness assistant. Generate a safe, balanced fitness workout plan for the user's demographic and fitness goal, focusing on their selected body area.

- Only use the allowed workouts: ${allowedWorkouts}
- For low weight or age, make the plan beginner-friendly.
- Avoid overworking the same muscle groups.
- Each workout must include: name, and recommended reps.
- The plan must include between ${data.minWorkouts} and ${data.maxWorkouts} workouts.
- Reply with ONLY valid JSON as shown in the example.
`;
    const userPrompt = `
Generate a fitness workout plan in JSON for a user with the following information:
Born on ${data.dateOfBirth},
Age is ${data.age} years old,
Sex is ${data.sex},
Weighing ${data.weight} kg,
Height of ${data.height} cm,
Fitness level of ${data.fitnessLevel},
Goal of ${data.goal},
Focusing on ${data.bodyFocus},

- Only use these workouts: ${allowedWorkouts}.
- The intensity is set to ${data.intensity}. The intensity range is from ${data.minIntensity} to ${data.maxIntensity}.
- Ensure a minimum of ${data.minRepsPerWorkout} reps and maximum of ${data.maxRepsPerWorkout} reps for each workout. Do not use 0 reps.
- The plan must be safe and suitable for the user's demographic.
- The plan must be concise and focused on the user's goal.
- The intensity and fitness level directly affects the number of reps.
- Do not guess the number of reps, use the intensity and fitness level to determine it.

Reply with ONLY this JSON format, no explanation, no extra text:
{
  "pushups": 10,
  "situps": 15,
}`;

    console.log("Making OpenAI API call...");
    let response;
    try {
      response = await makeHttpRequest("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: AI_MODEL,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt },
          ],
          temperature: AI_TEMPERATURE,
          max_tokens: AI_MAX_TOKENS,
          top_p: AI_TOP_P,
          frequency_penalty: AI_FREQUENCY_PENALTY,
          presence_penalty: AI_PRESENCE_PENALTY,
        }),
      });
    } catch (apiError) {
      console.error("OpenAI API request failed:", apiError);
      return createErrorResponse(
        500,
        "external_api_error",
        "AI service unavailable",
        "Unable to generate workout plan at this time. Please try again later."
      );
    }

    if (!response.ok) {
      const errorText = await response.text();
      console.error("OpenAI API error:", response.status, errorText);
      
      if (response.status === 429) {
        return createErrorResponse(
          429,
          "rate_limit",
          "Service temporarily unavailable",
          "Too many requests. Please try again in a few minutes."
        );
      } else if (response.status === 401) {
        return createErrorResponse(
          500,
          "authentication_error",
          "Authentication failed",
          "API configuration error"
        );
      } else {
        return createErrorResponse(
          500,
          "external_api_error",
          "AI service error",
          `OpenAI API returned status ${response.status}`
        );
      }
    }

    const responseData = await response.json();
    console.log("OpenAI response:", JSON.stringify(responseData, null, 2));
    
    const content = responseData?.choices?.[0]?.message?.content?.trim();
    if (!content) {
      return createErrorResponse(
        500,
        "ai_response_error",
        "Invalid AI response",
        "The AI service returned an empty response"
      );
    }
    
    // Parse the AI response
    let plan;
    try {
      // Clean the content to handle potential markdown formatting
      const cleanContent = content.replace(/```json\n?|\n?```/g, '').trim();
      plan = JSON.parse(cleanContent);

      console.log("Successfully generated fitness plan:", Object.keys(plan));
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify(plan),
      };
    } catch (err) {
      console.error("AI response parse error:", err);
      return createErrorResponse(
        500,
        "ai_response_error",
        "Failed to parse AI response",
        "The AI service returned an invalid JSON format"
      );
    }
  } catch (err) {
    console.error("Fitness plan generation error:", err);
    return createErrorResponse(
      500,
      "unhandled_exception",
      "Internal Server Error",
      err.message
    );
  }
};

// ========== QUOTE ENDPOINT ==========
const fetchMotivationalQuote = async () => {
  try {
    console.log("Fetching motivational quote...");
    const response = await makeHttpRequest("https://zenquotes.io/api/random");
    
    if (response.ok) {
      const data = await response.json();
      
      // Match Dart function behavior: return first quote if available
      if (Array.isArray(data) && data.length > 0 && data[0]) {
        const quote = {
          quote: data[0].q || '',
          author: data[0].a || 'Unknown'
        };
        
        console.log("Successfully fetched quote");
        return {
          statusCode: 200,
          headers: corsHeaders,
          body: JSON.stringify(quote),
        };
      }
    }
    
    console.log("Quote API returned empty or invalid data");
    // Return empty quote on failure (matching Dart null behavior)
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ 
        quote: '',
        author: ''
      }),
    };
    
  } catch (error) {
    console.error("Quote fetch error:", error);
    // Return empty quote on error (matching Dart catch behavior)
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ 
        quote: '',
        author: ''
      }),
    };
  }
};

// ========== IMAGE ENDPOINT ==========
const fetchMotivationImage = async () => {
  try {
    console.log("Fetching motivational image...");
    const secrets = await getSecrets();
    const accessKey = secrets.UNSPLASH_ACCESS_KEY;
    
    if (!accessKey) {
      console.warn("Unsplash access key not found, using fallback image");
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({ 
          imageUrl: "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=60",
          alt: "Fitness motivation - person exercising",
          photographer: "Fallback Image",
          photographerUrl: ""
        }),
      };
    }

    // Use more specific fitness-related queries
    const queries = ['fitness-workout', 'gym-motivation', 'exercise', 'fitness-training'];
    const randomQuery = queries[Math.floor(Math.random() * queries.length)];
    
    const response = await makeHttpRequest(
      `https://api.unsplash.com/photos/random?query=${randomQuery}&orientation=landscape`,
      {
        headers: { Authorization: `Client-ID ${accessKey}` }
      }
    );

    if (response.ok) {
      const photoData = await response.json();
      
      // Ensure we have a valid image URL
      const imageUrl = photoData.urls?.regular || photoData.urls?.small || photoData.urls?.thumb;
      
      if (imageUrl) {
        console.log("Successfully fetched image from Unsplash");
        return {
          statusCode: 200,
          headers: corsHeaders,
          body: JSON.stringify({ 
            imageUrl: imageUrl,
            alt: photoData.alt_description || "Motivational fitness image",
            photographer: photoData.user?.name || "Unknown",
            photographerUrl: photoData.user?.links?.html || ""
          }),
        };
      }
    }
    
    console.log("Unsplash API failed, using fallback image");
    // Return fallback image
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ 
        imageUrl: "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=60",
        alt: "Fitness motivation - person exercising",
        photographer: "Fallback Image",
        photographerUrl: ""
      }),
    };
    
  } catch (err) {
    console.error("Image fetch error:", err);
    
    // Return a reliable fallback image
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ 
        imageUrl: "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=60",
        alt: "Fitness motivation - person exercising",
        photographer: "Fallback Image",
        photographerUrl: ""
      }),
    };
  }
};

exports.handler = handler;