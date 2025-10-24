package com.located.app.presentation.family

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.located.app.data.model.FamilyMember
import com.located.app.data.model.FamilyRole

@Composable
fun FamilyManagementScreen(
    viewModel: FamilyViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showingInviteChild by remember { mutableStateOf(false) }
    var showingCreateFamily by remember { mutableStateOf(false) }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        if (uiState.currentFamily == null) {
            // No family - show create family option
            NoFamilyView(
                onCreateFamily = { showingCreateFamily = true }
            )
        } else {
            // Family exists - show family management
            FamilyView(
                family = uiState.currentFamily!!,
                familyMembers = uiState.familyMembers,
                onInviteChild = { showingInviteChild = true }
            )
        }
    }
    
    // Dialogs
    if (showingCreateFamily) {
        CreateFamilyDialog(
            onDismiss = { showingCreateFamily = false },
            onCreateFamily = { name ->
                viewModel.createFamily(name)
                showingCreateFamily = false
            }
        )
    }
    
    if (showingInviteChild) {
        InviteChildDialog(
            onDismiss = { showingInviteChild = false },
            onInviteChild = { childName ->
                // TODO: Implement invite child functionality
                showingInviteChild = false
            }
        )
    }
}

@Composable
fun NoFamilyView(
    onCreateFamily: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Home,
            contentDescription = "Family",
            modifier = Modifier.size(80.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text(
            text = "No Family Yet",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Create a family to start sharing locations with your loved ones",
            fontSize = 16.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(32.dp))
        
        Button(
            onClick = onCreateFamily,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Create Family")
        }
    }
}

@Composable
fun FamilyView(
    family: com.located.app.data.model.Family,
    familyMembers: Map<String, FamilyMember>,
    onInviteChild: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        // Family Header
        Card(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    imageVector = Icons.Default.Home,
                    contentDescription = "Family",
                    modifier = Modifier.size(50.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text(
                    text = family.name,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.SemiBold
                )
                
                Text(
                    text = "${familyMembers.size} members",
                    fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Family Members
        Text(
            text = "Family Members",
            fontSize = 18.sp,
            fontWeight = FontWeight.Medium
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(familyMembers.toList()) { (userId, member) ->
                FamilyMemberCard(
                    member = member,
                    userId = userId
                )
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Invite Child Button
        FloatingActionButton(
            onClick = onInviteChild,
            modifier = Modifier.align(Alignment.End)
        ) {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = "Invite Child"
            )
        }
    }
}

@Composable
fun FamilyMemberCard(
    member: FamilyMember,
    userId: String
) {
    Card(
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Member Avatar
            Surface(
                modifier = Modifier.size(48.dp),
                shape = MaterialTheme.shapes.circle,
                color = if (member.role == FamilyRole.PARENT) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.secondary
                }
            ) {
                Box(
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = member.name.take(1).uppercase(),
                        color = if (member.role == FamilyRole.PARENT) {
                            MaterialTheme.colorScheme.onPrimary
                        } else {
                            MaterialTheme.colorScheme.onSecondary
                        },
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            
            Spacer(modifier = Modifier.width(16.dp))
            
            // Member Info
            Column(
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = member.name,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium
                )
                
                Text(
                    text = member.role.name.lowercase().replaceFirstChar { it.uppercase() },
                    fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Text(
                    text = member.status.name.lowercase().replaceFirstChar { it.uppercase() },
                    fontSize = 12.sp,
                    color = when (member.status) {
                        com.located.app.data.model.InvitationStatus.ACCEPTED -> MaterialTheme.colorScheme.primary
                        com.located.app.data.model.InvitationStatus.PENDING -> MaterialTheme.colorScheme.secondary
                        com.located.app.data.model.InvitationStatus.DECLINED -> MaterialTheme.colorScheme.error
                    }
                )
            }
        }
    }
}

@Composable
fun CreateFamilyDialog(
    onDismiss: () -> Unit,
    onCreateFamily: (String) -> Unit
) {
    var familyName by remember { mutableStateOf("") }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create Family") },
        text = {
            Column {
                Text("Enter a name for your family")
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = familyName,
                    onValueChange = { familyName = it },
                    label = { Text("Family Name") },
                    singleLine = true
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = { 
                    if (familyName.isNotBlank()) {
                        onCreateFamily(familyName.trim())
                    }
                }
            ) {
                Text("Create")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

@Composable
fun InviteChildDialog(
    onDismiss: () -> Unit,
    onInviteChild: (String) -> Unit
) {
    var childName by remember { mutableStateOf("") }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Invite Child") },
        text = {
            Column {
                Text("Enter your child's name to send them an invitation")
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = childName,
                    onValueChange = { childName = it },
                    label = { Text("Child's Name") },
                    singleLine = true
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = { 
                    if (childName.isNotBlank()) {
                        onInviteChild(childName.trim())
                    }
                }
            ) {
                Text("Send Invitation")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
