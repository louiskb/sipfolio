# Sipfolio

Sipfolio is a social cocktail app where users can share, rate, and discover creative drinks from the community. Whether you're a home mixologist or just exploring new favorites, Sipfolio brings cocktail lovers together in one place.

## Features

- **Create & share cocktails** – Post your recipes with images, ingredients, and instructions.
- **AI-powered recipes** – Generate and refine cocktail recipes using SipSense Mix, powered by GPT-4o.
- **Rate & review** – Leave ratings, feedback, and images on community submissions.
- **Browse & discover** – Explore trending, top-rated, and newly added cocktails.
- **Favorites** – Bookmark cocktails to revisit later.
- **Follow system** – Follow other users and build your mixology network.
- **Gamification** – Earn achievements, badges, and points as you engage with the community.
- **Real-time chat** – WebSocket-powered chat for live interactions.
- **User profiles** – Personalized feeds and saved drinks.
- **Responsive design** – Optimized for both desktop and mobile.

## Tech Stack

- **Backend:** Ruby on Rails
- **Frontend:** HTML, CSS, JavaScript, Stimulus, Bootstrap
- **Database:** PostgreSQL
- **Storage:** Cloudinary (images via Active Storage)
- **Real-time:** Action Cable (WebSockets) + Redis
- **AI:** ruby_llm with Azure/OpenAI GPT-4o
- **Deployment:** Heroku
- **Authentication:** Devise
- **Authorization:** Pundit

## Setup

1. Clone the repository
2. Install dependencies — run `bundle install`
3. Set up environment variables — copy `.env.example` to `.env` and fill in the required values (see [Environment Variables](#environment-variables) below)
4. Set up the database — run `rails db:create db:migrate db:seed`
5. Start the server — run `rails server`

Visit http://localhost:3000 to start exploring.

## Environment Variables

Create a `.env` file at the root of the project with the following variables:

```
GITHUB_TOKEN=        # Azure AI inference API key (for SipSense Mix AI features)
CLOUDINARY_URL=      # Cloudinary credentials for image storage
REDIS_URL=           # Redis connection URL (required in production)
```

## License

This project is licensed under the [MIT License](LICENSE).
