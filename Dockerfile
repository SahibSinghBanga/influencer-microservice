FROM php:8.3

# Install required system packages and PHP extensions
RUN apt-get update && apt-get install -y \
    unzip \
    zip \
    libzip-dev \
    git \
    libc6-dev \
    libsasl2-dev \
    libsasl2-modules \
    libssl-dev \
    && docker-php-ext-install pdo pdo_mysql zip \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/local/bin --filename=composer

# Install librdkafka and PHP extension
RUN git clone https://github.com/edenhill/librdkafka.git \
    && cd librdkafka \
    && ./configure \
    && make \
    && make install \
    && pecl install rdkafka \
    && docker-php-ext-enable rdkafka \
    && rm -rf /librdkafka

WORKDIR /app

# Copy composer files first for caching
COPY composer.json composer.lock ./

# Install PHP dependencies without scripts (to avoid artisan errors)
RUN composer install --no-interaction --no-scripts --optimize-autoloader

# Copy rest of the application code
COPY . .

# Create required Laravel directories & set permissions
RUN mkdir -p bootstrap/cache \
    && mkdir -p storage/framework/{cache,sessions,views} \
    && chmod -R 775 bootstrap/cache storage

# Run Laravel post-install scripts
RUN composer run-script post-root-package-install \
    && composer run-script post-create-project-cmd \
    && composer dump-autoload \
    && php artisan package:discover --ansi || true