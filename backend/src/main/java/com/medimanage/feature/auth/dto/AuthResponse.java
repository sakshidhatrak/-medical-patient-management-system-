package com.medimanage.feature.auth.dto;

import com.medimanage.feature.user.dto.UserDto;

public record AuthResponse(String token, UserDto user) {}
